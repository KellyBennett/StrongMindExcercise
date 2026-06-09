require "rails_helper"

RSpec.describe IngestGithubEventsJob, type: :job do
  let(:client) { instance_double(Github::EventsClient) }
  let(:ingestion_logger) { instance_double(Github::IngestionLogger) }

  before do
    allow(Github::EventsClient).to receive(:new).and_return(client)
    allow(Github::IngestionLogger).to receive(:new).and_return(ingestion_logger)
  end

  it "skips polling while the cursor is waiting for the next poll window" do
    cursor = create(:github_ingestion_cursor, :waiting_for_next_poll)

    expect(client).not_to receive(:fetch_events)
    expect(ingestion_logger).to receive(:polling_skipped).with(cursor)

    described_class.perform_now

    expect(cursor.reload.next_poll_at).to be_present
  end

  it "skips polling while the GitHub rate limit reset is still in the future" do
    cursor = create(:github_ingestion_cursor, :rate_limited)

    expect(client).not_to receive(:fetch_events)
    expect(ingestion_logger).to receive(:polling_skipped).with(cursor)

    described_class.perform_now

    expect(cursor.reload.rate_limit_remaining).to eq(0)
  end

  it "uses the stored etag and records GitHub polling headers after an unchanged response" do
    cursor = create(:github_ingestion_cursor, :with_etag)
    response = github_events_response(
      status: 304,
      etag: nil,
      poll_interval: 90,
      rate_limit_remaining: 55,
      rate_limit_resets_at: 45.minutes.from_now
    )

    expect(client).to receive(:fetch_events).with(etag: "previous-etag").and_return(response)
    expect(ingestion_logger).to receive(:response_received).with(response)

    described_class.perform_now

    cursor.reload
    expect(cursor.etag).to eq("previous-etag")
    expect(cursor.next_poll_at).to be > 80.seconds.from_now
    expect(cursor.rate_limit_remaining).to eq(55)
  end

  it "backs off until the reset time when GitHub reports a depleted rate limit" do
    cursor = create(:github_ingestion_cursor)
    reset_at = 30.minutes.from_now
    response = github_events_response(
      status: 403,
      etag: nil,
      poll_interval: 60,
      rate_limit_remaining: 0,
      rate_limit_resets_at: reset_at
    )

    expect(client).to receive(:fetch_events).and_return(response)
    expect(ingestion_logger).to receive(:response_received).with(response)

    described_class.perform_now

    cursor.reload
    expect(cursor.rate_limit_remaining).to eq(0)
    expect(cursor.next_poll_at).to be_within(1.second).of(reset_at)
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
