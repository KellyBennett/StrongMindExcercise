module Github
  class ApiUrl
    HOST = "api.github.com"
    SCHEME = "https"
    ERROR_MESSAGE = "GitHub enrichment URL must be an https://api.github.com URL"

    def self.parse(url)
      new(url).to_uri
    end

    def initialize(url)
      @raw_url = url.to_s
    end

    def to_uri
      uri = URI(normalized_url)
      return uri if github_api_uri?(uri)

      raise ArgumentError, ERROR_MESSAGE
    rescue URI::InvalidURIError
      raise ArgumentError, ERROR_MESSAGE
    end

    private

    attr_reader :raw_url

    def normalized_url
      return raw_url unless raw_url.start_with?("#{SCHEME}://#{HOST}/")

      URI(raw_url)
      raw_url
    rescue URI::InvalidURIError
      "#{SCHEME}://#{HOST}#{encoded_path}#{query_string}"
    end

    def encoded_path
      path.split("/").map do |segment|
        URI.encode_www_form_component(segment).tr("+", "%20")
      end.join("/")
    end

    def path
      path_and_query.first
    end

    def query_string
      query = path_and_query.second
      query.present? ? "?#{query}" : ""
    end

    def path_and_query
      @path_and_query ||= raw_url.delete_prefix("#{SCHEME}://#{HOST}").split("?", 2)
    end

    def github_api_uri?(uri)
      uri.is_a?(URI::HTTPS) && uri.host == HOST
    end
  end
end
