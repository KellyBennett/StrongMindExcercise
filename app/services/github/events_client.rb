require "json"
require "net/http"

module Github
  class EventsClient
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

      http_response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request_for(uri, etag))
      end

      Response.new(
        status: http_response.code.to_i,
        events: events_from(http_response),
        etag: http_response["ETag"],
        poll_interval: poll_interval_from(http_response),
        rate_limit_remaining: integer_header(http_response, "X-RateLimit-Remaining"),
        rate_limit_resets_at: rate_limit_resets_at_from(http_response)
      )
    end

    private

    def events_uri
      URI(EVENTS_URL)
    end

    def request_for(uri, etag)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "strong-mind-challenge"
      request["If-None-Match"] = etag if etag.present?
      request
    end

    def events_from(http_response)
      return [] unless http_response.is_a?(Net::HTTPSuccess)

      JSON.parse(http_response.body)
    rescue JSON::ParserError
      []
    end

    def poll_interval_from(http_response)
      integer_header(http_response, "X-Poll-Interval") || DEFAULT_POLL_INTERVAL
    end

    def integer_header(http_response, header)
      value = http_response[header]
      value.to_i if value.present?
    end

    def rate_limit_resets_at_from(http_response)
      reset_epoch = integer_header(http_response, "X-RateLimit-Reset")
      Time.zone.at(reset_epoch) if reset_epoch.present?
    end
  end
end
