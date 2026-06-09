# StrongMind GitHub Events Challenge

Rails application that polls the public GitHub Events API, persists `PushEvent`
records for analysis, and enriches those events with GitHub actor and repository
metadata in background jobs.

## Requirements

- Ruby 3.4.9
- PostgreSQL
- Docker and Docker Compose, recommended for local review

The project was built in a VS Code dev container, but the root
`docker-compose.yml` is the easiest way to run it without depending on that
editor setup.

## Running Locally

Start the app and database:

```bash
docker compose up --build web
```

Then open:

- `http://localhost:3000/admin` for Administrate dashboards
- `http://localhost:3000/admin/github_push_events` for stored push events
- `http://localhost:3000/jobs` for Mission Control Jobs
- `http://localhost:3000/up` for the Rails health check

Run one ingestion pass manually:

```bash
docker compose run --rm ingest
```

Run the test suite:

```bash
docker compose run --rm test
```

The compose services use `mise exec -- ...` because the dev container image
installs the Ruby toolchain through mise. `mise exec` runs the command with the
Ruby version and related tools selected by the project.

## What The App Stores

`GithubPushEvent` stores the raw GitHub event payload plus structured columns
for fields the challenge calls out as queryable without JSON parsing:

- repository identifier: `github_repository_id`
- push identifier: `push_identifier`
- ref: `ref`
- head: `head`
- before: `before`

It also stores event-level actor and repository names for display. Enrichment
records are stored separately in `GithubActor` and `GithubRepository`, then
linked back to push events when available.

## Ingestion Flow

`IngestGithubEventsJob` polls `https://api.github.com/events` without
authentication.

The GitHub client captures:

- `ETag`
- `X-Poll-Interval`
- `X-RateLimit-Remaining`
- `X-RateLimit-Reset`

Those values are persisted in `GithubIngestionCursor`. The cursor decides when
polling is allowed, so the app can skip work while GitHub has asked us to wait
or while a rate limit reset is still in the future.

For each successful response, `Github::PushEventImporter` filters the response
to `PushEvent` records, validates the required fields, persists the event, and
enqueues `EnrichGithubPushEventJob` for newly-created records.

Malformed or unexpected events are skipped instead of failing the whole batch.
Network timeouts and DNS/socket failures use finite Active Job retries.

## Enrichment Flow

`EnrichGithubPushEventJob` fetches actor and repository resources from the API
URLs already present in the GitHub event payload.

Fan-out is intentionally bounded:

- Each new push event can trigger at most one actor fetch and one repository
  fetch.
- Existing `GithubActor` and `GithubRepository` records are reused by GitHub
  ID.
- If enrichment receives a rate-limit response, that enrichment job stops
  making additional GitHub requests.
- Enrichment runs in the background, so ingestion does not block on extra
  resource lookups.

The admin push-event view uses enriched data when present and falls back to the
original event payload when enrichment is unavailable.

## Idempotency And Restart Safety

Duplicate prevention happens at both the application and database layers.

- `github_push_events.github_event_id` has a unique index.
- `github_push_events.push_identifier` has a unique index.
- `github_actors.github_id` and `github_repositories.github_id` are unique.
- The importer checks for existing records before insert and also handles
  uniqueness races gracefully.
- Cursor state is stored in the database, so restarts keep the latest ETag,
  next poll time, and rate-limit reset time.
- Solid Queue stores jobs in PostgreSQL, so queued enrichment work survives app
  restarts.

This prevents duplicate events and data corruption. It does not currently apply
a retention policy to old push events or raw JSON payloads. For this exercise,
the tradeoff is to keep the complete ingested dataset available for review and
analysis. In a production service, a retention window or archival job would be
the next step to bound database growth.

## Rate Limiting And Fan-Out Tradeoffs

The primary ingestion loop follows GitHub's polling and rate-limit headers.
When GitHub says events are unchanged, the stored ETag is kept and no import
work runs. When GitHub reports a depleted rate limit, the cursor backs off until
the reset time.

Enrichment has lighter-weight fan-out control: it reuses previously fetched
actor/repository records and stops further fetches within a job after a
rate-limit response. There is not yet a global enrichment rate-limit cursor or
queue-wide concurrency limiter. The current design is intentionally simple and
appropriate for the challenge scale; a larger deployment should add global
enrichment backoff and stricter queue concurrency.

## Object Storage

This app does not currently use object storage.

Raw GitHub events are stored in PostgreSQL `jsonb`, and actor avatar URLs are
stored as durable references to GitHub-hosted images. Avatars are not downloaded,
so the app avoids repeated avatar downloads by design.

If object storage were required, the smallest production-like extension would be
to add Active Storage for raw event payload archives or cached avatar blobs,
store the blob references on the related records, and add a cleanup policy for
temporary or expired blobs.

## Logging And Operations

Logs are written around the major operational states:

- ingestion start
- polling skipped because of poll window or rate limit
- unchanged GitHub responses
- successful fetch counts
- imported and skipped push-event counts
- unexpected GitHub statuses
- enrichment start and finish
- enrichment rate-limit backoff
- transient failures and exhausted retries

Mission Control Jobs at `/jobs` can be used to inspect queued, scheduled, and
failed background jobs.

## Testing Strategy

The test suite uses RSpec, FactoryBot, WebMock, and VCR.

Key coverage:

- `Github::EventsClient` uses VCR cassettes at the GitHub HTTP boundary.
- `Github::ResourceClient` and `Github::ApiUrl` cover enrichment resource
  requests and URL validation.
- `Github::PushEventImporter` covers filtering, malformed events, duplicate
  handling, and enqueueing enrichment only for new records.
- `Github::PushEventEnricher` covers actor/repository enrichment, reuse of
  existing records, malformed URLs, non-success responses, and rate-limit
  fan-out behavior.
- `IngestGithubEventsJob` covers cursor-aware polling, ETag reuse, import
  orchestration, and rate-limit backoff.
- `GithubPushEvent` model specs prove the required fields are real database
  columns and directly queryable.
- Administrate request specs cover the enriched push-event admin display.

The VCR tests are intentionally kept at the client boundary. Higher-level
service and job tests use focused doubles/factories so failures point to the
application logic rather than to live GitHub API behavior.
