require "net/http"

class EnrichGithubPushEventJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, SocketError, wait: 1.minute, attempts: 3

  def perform(push_event)
    Github::PushEventEnricher.new.enrich(push_event)
  end
end
