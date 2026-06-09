require "rails_helper"

RSpec.describe EnrichGithubPushEventJob, type: :job do
  it "delegates enrichment to the push event enricher" do
    push_event = create(:github_push_event)
    enricher = instance_double(Github::PushEventEnricher)

    allow(Github::PushEventEnricher).to receive(:new).and_return(enricher)
    expect(enricher).to receive(:enrich).with(push_event)

    described_class.perform_now(push_event)
  end

  it "logs enrichment start and completion" do
    push_event = create(:github_push_event, github_event_id: "event-123")
    enricher = instance_double(Github::PushEventEnricher)
    rails_logger = instance_double(ActiveSupport::Logger)

    allow(Github::PushEventEnricher).to receive(:new).and_return(enricher)
    allow(enricher).to receive(:enrich).with(push_event)
    allow(Rails).to receive(:logger).and_return(rails_logger)

    expect(rails_logger).to receive(:info).with("Starting GitHub PushEvent enrichment for event-123")
    expect(rails_logger).to receive(:info).with("Finished GitHub PushEvent enrichment for event-123")

    described_class.perform_now(push_event)
  end
end
