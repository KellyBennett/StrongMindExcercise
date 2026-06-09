require "json"
require "net/http"

module Github
  class ResourceClient
    Response = Data.define(
      :status,
      :payload,
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

    def fetch(url:)
      uri = ApiUrl.parse(url)

      http_response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request_for(uri))
      end

      Response.new(
        status: http_response.code.to_i,
        payload: payload_from(http_response),
        rate_limit_remaining: integer_header(http_response, "X-RateLimit-Remaining"),
        rate_limit_resets_at: rate_limit_resets_at_from(http_response)
      )
    end

    private

    def request_for(uri)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "strong-mind-challenge"
      request
    end

    def payload_from(http_response)
      return {} unless http_response.is_a?(Net::HTTPSuccess)

      JSON.parse(http_response.body)
    rescue JSON::ParserError
      {}
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
