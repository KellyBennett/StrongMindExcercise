require "rails_helper"

RSpec.describe Github::EventsClient, :vcr do
  subject(:client) { described_class.new }

  around do |example|
    original_repository = ENV["GITHUB_REPOSITORY"]
    ENV["GITHUB_REPOSITORY"] = "rails/rails"
    example.run
  ensure
    ENV["GITHUB_REPOSITORY"] = original_repository
  end

  it "fetches public repository events without authentication and parses response metadata" do
    response = client.fetch_events(etag: nil)

    expect(response.status).to eq(200)
    expect(response.events).to be_an(Array)
    expect(response.etag).to be_present
    expect(response.poll_interval).to be_positive
    expect(response.rate_limit_remaining).to be >= 0
    expect(response.rate_limit_resets_at).to be_present
  end

  it "sends an etag as a conditional request header" do
    etag = "W/\"example-etag\""

    client.fetch_events(etag:)

    expect(
      a_request(:get, "https://api.github.com/repos/rails/rails/events")
        .with(headers: { "If-None-Match" => etag })
    ).to have_been_made
  end

  it "rejects malformed repository configuration" do
    ENV["GITHUB_REPOSITORY"] = "rails"

    expect { client.fetch_events(etag: nil) }
      .to raise_error(ArgumentError, "GITHUB_REPOSITORY must be formatted as owner/name")
  end
end
