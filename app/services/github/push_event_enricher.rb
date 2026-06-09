module Github
  class PushEventEnricher
    def initialize(resource_client: ResourceClient.new)
      @resource_client = resource_client
    end

    def enrich(push_event)
      actor = find_or_fetch_actor(push_event)
      repository = find_or_fetch_repository(push_event)

      push_event.update!(
        enriched_actor: actor,
        enriched_repository: repository
      )
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      Rails.logger.warn("GitHub PushEvent enrichment skipped for #{push_event.github_event_id}: #{error.message}")
    end

    private

    attr_reader :resource_client

    def find_or_fetch_actor(push_event)
      return unless push_event.actor_id.present?

      GithubActor.find_by(github_id: push_event.actor_id) || fetch_actor(push_event.raw_payload.dig("actor", "url"))
    end

    def find_or_fetch_repository(push_event)
      GithubRepository.find_by(github_id: push_event.github_repository_id) ||
        fetch_repository(push_event.raw_payload.dig("repo", "url"))
    end

    def fetch_actor(url)
      response = fetch_resource(url)
      return unless response&.success? && response.payload.present?

      payload = response.payload
      GithubActor.create!(
        github_id: payload.fetch("id"),
        login: payload.fetch("login"),
        avatar_url: payload["avatar_url"],
        html_url: payload["html_url"],
        raw_payload: payload
      )
    end

    def fetch_repository(url)
      response = fetch_resource(url)
      return unless response&.success? && response.payload.present?

      payload = response.payload
      GithubRepository.create!(
        github_id: payload.fetch("id"),
        name: payload.fetch("name"),
        full_name: payload["full_name"],
        html_url: payload["html_url"],
        description: payload["description"],
        owner_login: payload.dig("owner", "login"),
        raw_payload: payload
      )
    end

    def fetch_resource(url)
      return if url.blank? || rate_limited?

      response = resource_client.fetch(url:)
      if response.rate_limited?
        @rate_limited = true
        log_rate_limit(response)
      end

      response
    end

    def rate_limited?
      @rate_limited == true
    end

    def log_rate_limit(response)
      if response.rate_limit_resets_at.present?
        Rails.logger.warn("GitHub enrichment rate limited; backing off until #{response.rate_limit_resets_at.iso8601}")
      else
        Rails.logger.warn("GitHub enrichment rate limited")
      end
    end
  end
end
