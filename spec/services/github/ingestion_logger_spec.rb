require "rails_helper"

RSpec.describe Github::IngestionLogger do
  subject(:ingestion_logger) { described_class.new }

  let(:rails_logger) { instance_double(ActiveSupport::Logger) }

  before do
    allow(Rails).to receive(:logger).and_return(rails_logger)
  end

  it "logs when polling is paused until GitHub's requested poll window" do
    cursor = build(:github_ingestion_cursor, next_poll_at: Time.zone.parse("2026-06-09 12:00:00 UTC"))

    expect(rails_logger).to receive(:info).with(
      "Skipping GitHub events ingestion; next poll at 2026-06-09T12:00:00Z"
    )

    ingestion_logger.polling_skipped(cursor)
  end

  it "logs when polling is paused until the rate limit reset" do
    cursor = build(:github_ingestion_cursor, rate_limit_resets_at: Time.zone.parse("2026-06-09 12:30:00 UTC"))

    expect(rails_logger).to receive(:info).with(
      "Skipping GitHub events ingestion; rate limit resets at 2026-06-09T12:30:00Z"
    )

    ingestion_logger.polling_skipped(cursor)
  end

  it "logs unchanged responses" do
    expect(rails_logger).to receive(:info).with("GitHub events unchanged; no ingestion work needed")

    ingestion_logger.response_received(github_events_response(status: 304, etag: nil))
  end

  it "logs depleted rate limits" do
    expect(rails_logger).to receive(:warn).with("GitHub events ingestion rate limited; backing off")

    ingestion_logger.response_received(github_events_response(status: 403, rate_limit_remaining: 0))
  end

  it "logs successful fetches" do
    events = [{ "id" => "1" }, { "id" => "2" }]

    expect(rails_logger).to receive(:info).with("Fetched 2 GitHub events")

    ingestion_logger.response_received(github_events_response(events:))
  end

  it "logs unexpected responses" do
    expect(rails_logger).to receive(:warn).with("GitHub events ingestion received unexpected status 500")

    ingestion_logger.response_received(github_events_response(status: 500))
  end

  def github_events_response(
    status: 200,
    events: [],
    etag: "new-etag",
    poll_interval: 60,
    rate_limit_remaining: 60,
    rate_limit_resets_at: 1.hour.from_now
  )
    Github::EventsClient::Response.new(
      status:,
      events:,
      etag:,
      poll_interval:,
      rate_limit_remaining:,
      rate_limit_resets_at:
    )
  end
end
