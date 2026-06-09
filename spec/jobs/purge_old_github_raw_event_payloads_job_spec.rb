require "rails_helper"

RSpec.describe PurgeOldGithubRawEventPayloadsJob, type: :job do
  it "purges raw event payload objects older than the retention window" do
    old_event = create(:github_push_event)
    recent_event = create(:github_push_event)
    archiver = Github::RawEventArchiver.new

    travel_to 8.days.ago do
      archiver.archive(old_event)
    end

    archiver.archive(recent_event)

    described_class.perform_now(retention: 7.days)

    expect(old_event.reload.raw_event_payload).not_to be_attached
    expect(recent_event.reload.raw_event_payload).to be_attached
  end
end
