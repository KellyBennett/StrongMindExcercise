require "json"
require "stringio"

module Github
  class RawEventArchiver
    def archive(push_event)
      return if push_event.raw_event_payload.attached?

      payload_json = JSON.pretty_generate(push_event.raw_payload)

      push_event.raw_event_payload.attach(
        io: StringIO.new(payload_json),
        filename: "#{push_event.github_event_id}.json",
        content_type: "application/json",
        metadata: {
          github_event_id: push_event.github_event_id,
          push_identifier: push_event.push_identifier
        }
      )
    rescue ActiveStorage::IntegrityError, ActiveStorage::FileNotFoundError => error
      Rails.logger.warn("GitHub raw event archive skipped for #{push_event.github_event_id}: #{error.message}")
    end
  end
end
