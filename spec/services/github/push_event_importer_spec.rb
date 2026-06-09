require "rails_helper"

RSpec.describe Github::PushEventImporter do
  subject(:importer) { described_class.new }

  it "persists raw and structured data for push events" do
    result = importer.import([ push_event ])

    event = GithubPushEvent.sole
    expect(result.imported_count).to eq(1)
    expect(result.skipped_count).to eq(0)
    expect(event.github_event_id).to eq("event-1")
    expect(event.github_repository_id).to eq(12_345)
    expect(event.repository_name).to eq("rails/rails")
    expect(event.push_identifier).to eq(67_890)
    expect(event.ref).to eq("refs/heads/main")
    expect(event.head).to eq("HEAD_SHA")
    expect(event.before).to eq("BEFORE_SHA")
    expect(event.raw_payload).to eq(push_event)
  end

  it "ignores non-push events" do
    result = importer.import([ push_event.merge("type" => "IssuesEvent") ])

    expect(result.imported_count).to eq(0)
    expect(result.skipped_count).to eq(1)
    expect(GithubPushEvent.count).to eq(0)
  end

  it "does not duplicate an existing GitHub event" do
    create(:github_push_event, github_event_id: "event-1", push_identifier: 111)

    result = importer.import([ push_event ])

    expect(result.imported_count).to eq(0)
    expect(result.skipped_count).to eq(1)
    expect(GithubPushEvent.count).to eq(1)
  end

  it "does not duplicate an existing push identifier" do
    create(:github_push_event, github_event_id: "event-2", push_identifier: 67_890)

    result = importer.import([ push_event ])

    expect(result.imported_count).to eq(0)
    expect(result.skipped_count).to eq(1)
    expect(GithubPushEvent.count).to eq(1)
  end

  it "skips malformed push events without raising" do
    malformed_event = push_event.except("payload")
    result = nil

    expect { result = importer.import([ malformed_event ]) }.not_to raise_error
    expect(result.imported_count).to eq(0)
    expect(result.skipped_count).to eq(1)
    expect(GithubPushEvent.count).to eq(0)
  end

  def push_event
    {
      "id" => "event-1",
      "type" => "PushEvent",
      "repo" => {
        "id" => 12_345,
        "name" => "rails/rails"
      },
      "actor" => {
        "id" => 456,
        "login" => "contributor"
      },
      "payload" => {
        "push_id" => 67_890,
        "ref" => "refs/heads/main",
        "head" => "HEAD_SHA",
        "before" => "BEFORE_SHA"
      }
    }
  end
end
