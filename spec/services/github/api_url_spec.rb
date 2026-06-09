require "rails_helper"

RSpec.describe Github::ApiUrl do
  it "parses valid GitHub API URLs" do
    uri = described_class.parse("https://api.github.com/repos/rails/rails")

    expect(uri.scheme).to eq("https")
    expect(uri.host).to eq("api.github.com")
    expect(uri.path).to eq("/repos/rails/rails")
  end

  it "escapes public event API URLs that contain bot login brackets" do
    uri = described_class.parse("https://api.github.com/users/renovate[bot]")

    expect(uri.to_s).to eq("https://api.github.com/users/renovate%5Bbot%5D")
  end

  it "rejects non-GitHub API URLs" do
    expect { described_class.parse("https://example.com/users/contributor") }
      .to raise_error(ArgumentError, Github::ApiUrl::ERROR_MESSAGE)
  end

  it "rejects malformed non-GitHub URLs" do
    expect { described_class.parse("not a url") }
      .to raise_error(ArgumentError, Github::ApiUrl::ERROR_MESSAGE)
  end
end
