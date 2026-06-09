require "rails_helper"

RSpec.describe Github::EventsClient, :vcr do
  subject(:client) { described_class.new }

  it "fetches public GitHub events without authentication and parses response metadata" do
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
      a_request(:get, "https://api.github.com/events")
        .with(headers: { "If-None-Match" => etag })
    ).to have_been_made
  end
end
