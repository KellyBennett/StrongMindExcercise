require "rails_helper"
require "json"

RSpec.describe Github::RawEventArchiver do
  subject(:archiver) { described_class.new }

  it "stores the raw event payload as an attached JSON object" do
    push_event = create(:github_push_event, github_event_id: "event-123")

    archiver.archive(push_event)

    attachment = push_event.reload.raw_event_payload
    expect(attachment).to be_attached
    expect(attachment.filename.to_s).to eq("event-123.json")
    expect(attachment.content_type).to eq("application/json")
    expect(JSON.parse(attachment.download)).to eq(push_event.raw_payload)
    expect(attachment.blob.metadata).to include(
      "github_event_id" => "event-123",
      "push_identifier" => push_event.push_identifier
    )
  end

  it "does not store another object when the payload is already attached" do
    push_event = create(:github_push_event)

    archiver.archive(push_event)

    expect { archiver.archive(push_event.reload) }
      .not_to change(ActiveStorage::Attachment, :count)
  end
end
