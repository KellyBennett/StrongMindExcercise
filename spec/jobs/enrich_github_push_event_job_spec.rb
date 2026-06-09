require "rails_helper"

RSpec.describe EnrichGithubPushEventJob, type: :job do
  it "delegates enrichment to the push event enricher" do
    push_event = create(:github_push_event)
    enricher = instance_double(Github::PushEventEnricher)

    allow(Github::PushEventEnricher).to receive(:new).and_return(enricher)
    expect(enricher).to receive(:enrich).with(push_event)

    described_class.perform_now(push_event)
  end
end
