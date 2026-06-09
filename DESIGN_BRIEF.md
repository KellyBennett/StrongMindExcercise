# Design Brief

## How I Understood The Problem

The challenge is to build a small but durable ingestion service for GitHub's
public Events API. The application should periodically fetch public events,
persist `PushEvent` records in PostgreSQL, make the required push fields
directly queryable, and provide enough operational visibility for a reviewer to
confirm that ingestion, enrichment, and background processing are working.

I interpreted the problem as an internal analytics ingestion workflow rather
than as a public API proxy. The app owns its polling state, stores the events it
has already accepted, and exposes those records through an admin UI and Rails
console queries. Because the public Events API is unauthenticated and globally
rate limited, correctness depends less on fetching constantly and more on
respecting GitHub's polling guidance, avoiding duplicate records, and surviving
ordinary restarts without losing the cursor or queued work.

## Proposed Architecture

The implementation is a Rails app backed by PostgreSQL, Solid Queue, and Active
Storage. The ingestion path is intentionally split into small collaborators:

- `IngestGithubEventsJob` orchestrates one polling pass. It checks whether
  polling is currently allowed, calls the GitHub events client, updates the
  cursor from response metadata, logs the outcome, and delegates event
  persistence.
- `Github::EventsClient` performs the unauthenticated HTTP request to
  `https://api.github.com/events`. It sends the stored ETag when present and
  returns both the event payload and relevant response metadata.
- `GithubIngestionCursor` stores durable polling state: the current ETag, next
  allowed poll time, remaining rate-limit count, and reset time.
- `Github::PushEventImporter` filters the response down to `PushEvent` records,
  validates the fields the challenge cares about, skips malformed or duplicate
  records, writes accepted events, archives the raw event payload, and enqueues
  enrichment.
- `EnrichGithubPushEventJob` and `Github::PushEventEnricher` fetch actor and
  repository resources from URLs already included in the event payload, reusing
  previously fetched records when possible.

The main persisted record is `GithubPushEvent`. It stores the raw event JSON,
the required queryable columns (`github_repository_id`, `push_identifier`,
`ref`, `head`, and `before`), display-friendly actor/repository fields, and
optional links to enriched `GithubActor` and `GithubRepository` records. The
admin UI gives reviewers a quick way to inspect events, enrichment records,
cursor state, and background jobs.

## Key Tradeoffs And Assumptions

We favored a simple polling service with strong local guarantees over a larger
distributed ingestion system. The app polls every minute through Solid Queue,
but the durable cursor can skip a scheduled run when GitHub asks us to wait.
This keeps the recurrence easy to reason about while still respecting response
headers.

We store both structured columns and raw JSON. The structured columns make the
challenge fields directly queryable without JSON traversal, while the raw JSON
keeps the source event available for audit, debugging, and future fields. Active
Storage also archives a JSON object copy of newly imported raw events, which
demonstrates how the same app could point durable raw-event storage at S3 or GCS
in production.

Enrichment is deliberately asynchronous and best effort. Ingestion should not
block on extra actor or repository lookups. If enrichment cannot fetch a
resource because of malformed URLs, non-success responses, duplicate races, or
rate limits, the original push event remains useful and visible.

We assume the reviewer will run the app locally with Docker Compose, use the
admin UI for inspection, and treat GitHub API availability/rate limits as real
external constraints rather than test flakiness.

## Rate Limits And Durability

The ingestion client captures `ETag`, `X-Poll-Interval`,
`X-RateLimit-Remaining`, and `X-RateLimit-Reset`. `IngestGithubEventsJob`
persists those values into `GithubIngestionCursor` after each response. Before
polling, the job asks the cursor whether polling is available. If the next poll
time or rate-limit reset time is still in the future, the job logs the skip and
does no network work.

Duplicate prevention is handled in both application logic and the database.
`github_event_id` and `push_identifier` are unique, and the importer handles
uniqueness races by skipping the conflicting event instead of failing the whole
batch. Malformed or unexpected events are skipped for the same reason: one bad
payload should not prevent valid events from being imported.

Durability comes from PostgreSQL-backed state. The ingestion cursor survives
app restarts, `GithubPushEvent` rows survive process failures, and Solid Queue
stores queued enrichment jobs in the database. Transient network failures use
finite Active Job retries, which gives temporary GitHub or network issues a
chance to recover without retrying forever.

## What I Intentionally Did Not Build

I did not build a global enrichment rate-limit coordinator or queue-wide
concurrency limiter. Enrichment currently reuses existing actor/repository
records and stops further requests within a job after a rate-limit response. A
production version of this app should add global enrichment backoff and stricter queue
controls.

I did not build a public JSON API, search product, analytics dashboard, or
multi-tenant user experience. The admin UI and console queries are sufficient
for reviewing the ingestion behavior and stored data.

I did not download avatar images. The app stores GitHub avatar URLs and renders
those durable references directly, avoiding unnecessary network and storage
work.

I did not make retention mandatory for the core push-event table. The project
includes raw-event object purging support, but keeps the ingested database rows
available for review. In production, a clear retention policy would be the next
step to bound storage growth.
