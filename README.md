# StrongMind GitHub Events Challenge

Rails application that polls the public GitHub Events API, persists `PushEvent`
records for analysis, and enriches those events with GitHub actor and repository
metadata in background jobs.

## Requirements

- Docker and Docker Compose

Ruby 3.4.9, PostgreSQL, and the application dependencies are provided by the
Docker image and compose services.

The project was built in a VS Code dev container, but the root
`docker-compose.yml` is the recommended way to run it for review without
depending on that editor setup.

## Running Locally

Start the app and database:

```bash
docker compose up --build web
```

Then open:

- `http://localhost:3000/admin` for an Admin dashboard
- `http://localhost:3000/admin/github_push_events` for stored push events
- `http://localhost:3000/jobs` for Mission Control Jobs (username: `dev`, password: `secret`)
- `http://localhost:3000/up` for the Rails health check

Run one cursor-aware ingestion pass manually:

```bash
docker compose run --rm ingest
```

Note that the app is configured to do automatic ingestion every 1 minute, so you're very likely to hit a rate-limit if you run the ingest manually like this. This is expected.

Run the test suite:

```bash
docker compose run --rm test
```

## How To Verify It's Working

Start the web app and database:

```bash
docker compose up --build web
```

After the container is built and dependencies are installed, you'll start seeing application logs right away. The app is configured to automatically begin ingesting, and will continue to ingest at a frequency defined in `config/recurring.yml`.

In another terminal, you can choose to run one cursor-aware ingestion pass:

```bash
docker compose run --rm ingest
```

The command respects the stored GitHub polling cursor, so it may
log that ingestion was skipped when GitHub has asked the app to wait or when the
unauthenticated API rate limit is still resetting. If GitHub polling is
available and returns new public `PushEvent` records, database rows should
appear immediately after that command completes. Enrichment jobs may take
another few seconds to populate actor and repository metadata because that work
runs in the background queue.

### Verifying via UI

This is the recommended way to see everything working. I've provided two UIs for you to easily see what's been created, and you can poke around to see the various pieces in action.

Open

- `http://localhost:3000/admin` shows created records stored in Postgres. After the app has been running for a minute, you should start to see records populating here. You'll also see enriched post data in these views after the EnrichPosts jobs have run in the background.
- `http://localhost:3000/jobs` for queued, finished, or failed background jobs

### Verifying via Logs

Expected ingestion logs include messages like:

- `Starting GitHub events ingestion; etag missing`
- `Fetched N GitHub events`
- `Imported N GitHub PushEvent records; skipped N`

Depending on GitHub's API state, you may also see:

- `GitHub events unchanged; no ingestion work needed`
- `Skipping GitHub events ingestion; next poll at ...`
- `GitHub events ingestion rate limited; backing off`

Expected enrichment logs include:

- `Starting GitHub PushEvent enrichment for ...`
- `Finished GitHub PushEvent enrichment for ...`

### Verifying Records From The Rails Console

With the web service running in another terminal, open a Rails console:

```bash
docker compose exec web bash -lc "mise exec -- bin/rails console"
```

Then you can run rails commands, such as:

```ruby
GithubIngestionCursor.public_events

GithubPushEvent.count

GithubPushEvent.order(created_at: :desc).limit(5).pluck(:github_event_id, :repository_name, :push_identifier)

GithubActor.count

GithubRepository.count

ActiveStorage::Attachment.where(name: "raw_event_payload", record_type: "GithubPushEvent").count
```

The most important table is `github_push_events`; it contains the raw GitHub
payload plus the required queryable fields: `github_repository_id`,
`push_identifier`, `ref`, `head`, and `before`. `github_ingestion_cursors`
stores the latest ETag, next poll time, and rate-limit state. Enrichment data
appears in `github_actors` and `github_repositories` when the background job is
able to fetch those resources.

## Optional Dev Container

For day-to-day development, you would open the repository in VS Code and choose
`Dev Containers: Reopen in Container`.

The dev container keeps local requirements minimal while providing the app
runtime and developer tooling:

- Ruby, Rails dependencies, PostgreSQL, Selenium, and Postgres client tools
- GitHub CLI and Docker access from inside the container
- forwarded ports for Rails (`3000`) and PostgreSQL (`5432`)
- Ruby LSP with RuboCop formatting on save
- automatic setup via `bin/setup --skip-server`

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

This app uses Active Storage to store a JSON object copy of each newly imported
raw GitHub event payload.

In local development and tests, Active Storage uses the Rails disk service. In a
production deployment, the same attachment code can point at S3, GCS, or another
Active Storage service by changing `config/storage.yml` and the environment's
`config.active_storage.service`.

Each `GithubPushEvent` has one `raw_event_payload` attachment. The database
still stores structured query columns and the `jsonb` payload for analysis, but
the Active Storage attachment gives the raw event a durable object reference.

Object writes are bounded to new events:

- duplicate GitHub events are skipped before object storage is touched
- existing raw-event attachments are not written again
- `PurgeOldGithubRawEventPayloadsJob` can remove raw-event objects older than a
  retention window while leaving the database record and queryable fields intact

Avatars are not downloaded. The app stores GitHub avatar URLs and renders those
durable references directly, which avoids unnecessary avatar re-downloads.

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
