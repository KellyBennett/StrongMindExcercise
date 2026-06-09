module Github
  class PushEventImporter
    Result = Data.define(:imported_count, :skipped_count)

    def import(events)
      imported_count = 0
      skipped_count = 0

      events.each do |event|
        attributes = attributes_from(event)

        if attributes.blank? || already_imported?(attributes)
          skipped_count += 1
          next
        end

        GithubPushEvent.create!(attributes)
        imported_count += 1
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        skipped_count += 1
      end

      Result.new(imported_count:, skipped_count:)
    end

    private

    def attributes_from(event)
      return unless event["type"] == "PushEvent"

      repo = event.fetch("repo")
      payload = event.fetch("payload")
      actor = event["actor"] || {}

      {
        github_event_id: event.fetch("id"),
        github_repository_id: repo.fetch("id"),
        repository_name: repo.fetch("name"),
        push_identifier: payload.fetch("push_id"),
        ref: payload.fetch("ref"),
        head: payload.fetch("head"),
        before: payload.fetch("before"),
        actor_id: actor["id"],
        actor_login: actor["login"],
        raw_payload: event
      }
    rescue KeyError, NoMethodError
      nil
    end

    def already_imported?(attributes)
      GithubPushEvent.exists?(github_event_id: attributes[:github_event_id]) ||
        GithubPushEvent.exists?(push_identifier: attributes[:push_identifier])
    end
  end
end
