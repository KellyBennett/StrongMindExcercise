require "net/http"

class EnrichGithubPushEventJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, SocketError, wait: 1.minute, attempts: 3 do |_job, error|
    Rails.logger.error("GitHub PushEvent enrichment retries exhausted: #{error.class} - #{error.message}")
  end

  discard_on ActiveJob::DeserializationError do |_job, error|
    Rails.logger.warn("Discarding GitHub PushEvent enrichment job: #{error.class} - #{error.message}")
  end

  def perform(push_event)
    Rails.logger.info("Starting GitHub PushEvent enrichment for #{push_event.github_event_id}")
    Github::PushEventEnricher.new.enrich(push_event)
    Rails.logger.info("Finished GitHub PushEvent enrichment for #{push_event.github_event_id}")
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => error
    Rails.logger.error(
      "GitHub PushEvent enrichment failed for #{push_event.github_event_id}: #{error.class} - #{error.message}"
    )
    raise
  end
end
