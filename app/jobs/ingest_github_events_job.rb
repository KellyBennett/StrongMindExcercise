class IngestGithubEventsJob < ApplicationJob
  queue_as :default

  def perform
    cursor = GithubIngestionCursor.public_events
    now = Time.current

    unless cursor.polling_available?(now:)
      ingestion_logger.polling_skipped(cursor)
      return
    end

    response = events_client.fetch_events(etag: cursor.etag)

    update_cursor_from(response, cursor)
    ingestion_logger.response_received(response)
  end

  private

  def events_client
    Github::EventsClient.new
  end

  def ingestion_logger
    Github::IngestionLogger.new
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
