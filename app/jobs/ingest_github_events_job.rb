require "net/http"

class IngestGithubEventsJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, SocketError, wait: 1.minute, attempts: 3 do |_job, error|
    Github::IngestionLogger.new.retries_exhausted(error)
  end

  def perform
    cursor = GithubIngestionCursor.public_events
    now = Time.current

    unless cursor.polling_available?(now:)
      ingestion_logger.polling_skipped(cursor)
      return
    end

    ingestion_logger.ingestion_started(cursor)
    response = events_client.fetch_events(etag: cursor.etag)

    update_cursor_from(response, cursor)
    ingestion_logger.response_received(response)
    import_push_events(response) if response.success?
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => error
    ingestion_logger.ingestion_failed(error)
    raise
  end

  private

  def events_client
    Github::EventsClient.new
  end

  def ingestion_logger
    Github::IngestionLogger.new
  end

  def push_event_importer
    Github::PushEventImporter.new
  end

  def import_push_events(response)
    result = push_event_importer.import(response.events)

    ingestion_logger.push_events_imported(result)
  end

  def update_cursor_from(response, cursor)
    attributes = {
      etag: response.etag.presence || cursor.etag,
      next_poll_at: Time.current + response.poll_interval.seconds,
      rate_limit_remaining: response.rate_limit_remaining,
      rate_limit_resets_at: response.rate_limit_resets_at
    }.compact

    if response.rate_limited?
      attributes[:next_poll_at] = response.rate_limit_resets_at if response.rate_limit_resets_at.present?
      attributes[:rate_limit_remaining] = 0
    end

    cursor.update!(attributes)
  end
end
