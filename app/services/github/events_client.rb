module Github
  class EventsClient < ApiClient
    EVENTS_URL = "https://api.github.com/events"
    DEFAULT_POLL_INTERVAL = 60

    Response = Data.define(
      :status,
      :events,
      :etag,
      :poll_interval,
      :rate_limit_remaining,
      :rate_limit_resets_at
    ) do
      def success?
        status == 200
      end

      def not_modified?
        status == 304
      end

      def rate_limited?
        status.in?([ 403, 429 ]) && rate_limit_remaining.to_i <= 0
      end
    end

    def fetch_events(etag:)
      uri = events_uri
      response = get_json(uri, headers: request_headers(etag), default_payload: [])

      Response.new(
        status: response.status,
        events: response.payload,
        etag: response.etag,
        poll_interval: response.poll_interval || DEFAULT_POLL_INTERVAL,
        rate_limit_remaining: response.rate_limit_remaining,
        rate_limit_resets_at: response.rate_limit_resets_at
      )
    end

    private

    def events_uri
      URI(EVENTS_URL)
    end

    def request_headers(etag)
      { "If-None-Match" => etag }
    end
  end
end
