module Github
  class ResourceClient < ApiClient
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
      response = get_json(uri, default_payload: {})

      Response.new(
        status: response.status,
        payload: response.payload,
        rate_limit_remaining: response.rate_limit_remaining,
        rate_limit_resets_at: response.rate_limit_resets_at
      )
    end
  end
end
