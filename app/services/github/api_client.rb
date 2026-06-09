require "json"
require "net/http"

module Github
  class ApiClient
    USER_AGENT = "strong-mind-challenge"

    Response = Data.define(
      :status,
      :payload,
      :etag,
      :poll_interval,
      :rate_limit_remaining,
      :rate_limit_resets_at
    ) do
      def success?
        status == 200
      end

      def rate_limited?
        status.in?([ 403, 429 ]) && rate_limit_remaining.to_i <= 0
      end
    end

    private

    def get_json(uri, headers: {}, default_payload:)
      http_response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request_for(uri, headers))
      end

      Response.new(
        status: http_response.code.to_i,
        payload: payload_from(http_response, default_payload:),
        etag: http_response["ETag"],
        poll_interval: integer_header(http_response, "X-Poll-Interval"),
        rate_limit_remaining: integer_header(http_response, "X-RateLimit-Remaining"),
        rate_limit_resets_at: rate_limit_resets_at_from(http_response)
      )
    end

    def request_for(uri, headers)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      headers.each { |name, value| request[name] = value if value.present? }
      request
    end

    def payload_from(http_response, default_payload:)
      return default_payload unless http_response.is_a?(Net::HTTPSuccess)

      JSON.parse(http_response.body)
    rescue JSON::ParserError
      default_payload
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
