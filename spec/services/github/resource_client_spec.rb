require "rails_helper"

RSpec.describe Github::ResourceClient do
  subject(:client) { described_class.new }

  it "fetches and parses GitHub API resources" do
    stub_request(:get, "https://api.github.com/users/contributor")
      .to_return(
        status: 200,
        body: { "id" => 456, "login" => "contributor" }.to_json,
        headers: {
          "X-RateLimit-Remaining" => "59",
          "X-RateLimit-Reset" => 1.hour.from_now.to_i.to_s
        }
      )

    response = client.fetch(url: "https://api.github.com/users/contributor")

    expect(response).to be_success
    expect(response.payload).to include("login" => "contributor")
    expect(response.rate_limit_remaining).to eq(59)
    expect(response.rate_limit_resets_at).to be_present
  end

  it "returns an empty payload for invalid JSON" do
    stub_request(:get, "https://api.github.com/users/contributor")
      .to_return(status: 200, body: "not json", headers: {})

    response = client.fetch(url: "https://api.github.com/users/contributor")

    expect(response.payload).to eq({})
  end
end
