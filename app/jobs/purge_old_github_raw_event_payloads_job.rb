class PurgeOldGithubRawEventPayloadsJob < ApplicationJob
  queue_as :default

  DEFAULT_RETENTION = 30.days

  def perform(retention: DEFAULT_RETENTION)
    cutoff = Time.current - retention

    ActiveStorage::Attachment
      .where(name: "raw_event_payload", record_type: "GithubPushEvent")
      .where(created_at: ...cutoff)
      .find_each do |attachment|
        attachment.purge
      end
  end
end
