module Github
  class IngestionLogger
    def ingestion_started(cursor)
      etag_state = cursor.etag.present? ? "present" : "missing"

      Rails.logger.info("Starting GitHub events ingestion; etag #{etag_state}")
    end

    def polling_skipped(cursor)
      if cursor.rate_limited?
        Rails.logger.info("Skipping GitHub events ingestion; rate limit resets at #{cursor.rate_limit_resets_at.iso8601}")
      elsif cursor.polling_paused?
        Rails.logger.info("Skipping GitHub events ingestion; next poll at #{cursor.next_poll_at.iso8601}")
      else
        Rails.logger.info("Skipping GitHub events ingestion")
      end
    end

    def response_received(response)
      if response.not_modified?
        Rails.logger.info("GitHub events unchanged; no ingestion work needed")
      elsif response.rate_limited?
        Rails.logger.warn("GitHub events ingestion rate limited; backing off")
      elsif response.success?
        Rails.logger.info("Fetched #{response.events.count} GitHub events")
      else
        Rails.logger.warn("GitHub events ingestion received unexpected status #{response.status}")
      end
    end

    def push_events_imported(result)
      Rails.logger.info(
        "Imported #{result.imported_count} GitHub PushEvent records; skipped #{result.skipped_count}"
      )
    end

    def ingestion_failed(error)
      Rails.logger.error("GitHub events ingestion failed: #{error.class} - #{error.message}")
    end

    def retries_exhausted(error)
      Rails.logger.error("GitHub events ingestion retries exhausted: #{error.class} - #{error.message}")
    end
  end
end
