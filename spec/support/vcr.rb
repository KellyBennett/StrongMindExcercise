require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join("spec/fixtures/vcr_cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri]
  }
end

WebMock.disable_net_connect!(allow_localhost: true)
