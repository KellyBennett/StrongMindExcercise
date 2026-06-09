require "rails_helper"
require "net/http"

RSpec.describe Github::IngestionLogger do
  subject(:ingestion_logger) { described_class.new }

  let(:rails_logger) { instance_double(ActiveSupport::Logger) }

  before do
    allow(Rails).to receive(:logger).and_return(rails_logger)
  end

  it "logs ingestion starts" do
    cursor = build(:github_ingestion_cursor, etag: "previous-etag")

    expect(rails_logger).to receive(:info).with("Starting GitHub events ingestion; etag present")

    ingestion_logger.ingestion_started(cursor)
  end

  it "logs when polling is paused until GitHub's requested poll window" do
    next_poll_at = 1.hour.from_now
    cursor = build(:github_ingestion_cursor, next_poll_at:)

    expect(rails_logger).to receive(:info).with(
      "Skipping GitHub events ingestion; next poll at #{next_poll_at.iso8601}"
    )

    ingestion_logger.polling_skipped(cursor)
  end

  it "logs when polling is paused until the rate limit reset" do
    rate_limit_resets_at = 30.minutes.from_now
    cursor = build(:github_ingestion_cursor, rate_limit_remaining: 0, rate_limit_resets_at:)

    expect(rails_logger).to receive(:info).with(
      "Skipping GitHub events ingestion; rate limit resets at #{rate_limit_resets_at.iso8601}"
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
    events = [ { "id" => "1" }, { "id" => "2" } ]

    expect(rails_logger).to receive(:info).with("Fetched 2 GitHub events")

    ingestion_logger.response_received(github_events_response(events:))
  end

  it "logs unexpected responses" do
    expect(rails_logger).to receive(:warn).with("GitHub events ingestion received unexpected status 500")

    ingestion_logger.response_received(github_events_response(status: 500))
  end

  it "logs imported push event counts" do
    result = Github::PushEventImporter::Result.new(imported_count: 2, skipped_count: 3)

    expect(rails_logger).to receive(:info).with("Imported 2 GitHub PushEvent records; skipped 3")

    ingestion_logger.push_events_imported(result)
  end

  it "logs ingestion failures" do
    error = Net::OpenTimeout.new("execution expired")

    expect(rails_logger).to receive(:error).with(
      "GitHub events ingestion failed: Net::OpenTimeout - execution expired"
    )

    ingestion_logger.ingestion_failed(error)
  end

  it "logs exhausted ingestion retries" do
    error = SocketError.new("getaddrinfo failed")

    expect(rails_logger).to receive(:error).with(
      "GitHub events ingestion retries exhausted: SocketError - getaddrinfo failed"
    )

    ingestion_logger.retries_exhausted(error)
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
