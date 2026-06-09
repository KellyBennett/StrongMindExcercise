require "rails_helper"

RSpec.describe Github::PushEventEnricher do
  subject(:enricher) { described_class.new(resource_client:) }

  let(:resource_client) { instance_double(Github::ResourceClient) }

  it "fetches actor and repository data from payload URLs and links them to the push event" do
    push_event = create(:github_push_event, actor_id: 456, github_repository_id: 12_345)

    expect(resource_client).to receive(:fetch)
      .with(url: "https://api.github.com/users/contributor")
      .and_return(github_resource_response(actor_payload))
    expect(resource_client).to receive(:fetch)
      .with(url: "https://api.github.com/repos/rails/rails")
      .and_return(github_resource_response(repository_payload))

    enricher.enrich(push_event)

    push_event.reload
    expect(push_event.enriched_actor.github_id).to eq(456)
    expect(push_event.enriched_actor.login).to eq("contributor")
    expect(push_event.enriched_repository.github_id).to eq(12_345)
    expect(push_event.enriched_repository.full_name).to eq("rails/rails")
  end

  it "reuses existing actor and repository records without fetching them again" do
    actor = create(:github_actor, github_id: 456)
    repository = create(:github_repository, github_id: 12_345)
    push_event = create(:github_push_event, actor_id: 456, github_repository_id: 12_345)

    expect(resource_client).not_to receive(:fetch)

    enricher.enrich(push_event)

    push_event.reload
    expect(push_event.enriched_actor).to eq(actor)
    expect(push_event.enriched_repository).to eq(repository)
  end

  it "skips malformed enrichment URLs without raising" do
    push_event = create(
      :github_push_event,
      raw_payload: build(:github_push_event).raw_payload.deep_merge(
        "actor" => { "url" => "https://example.com/users/contributor" },
        "repo" => { "url" => "https://example.com/repos/rails/rails" }
      )
    )

    expect(resource_client).to receive(:fetch)
      .and_raise(ArgumentError, "GitHub enrichment URL must be an https://api.github.com URL")

    expect { enricher.enrich(push_event) }.not_to raise_error
    expect(push_event.reload.enriched_actor).to be_nil
    expect(push_event.enriched_repository).to be_nil
  end

  it "does not create enrichment records when GitHub does not return success" do
    push_event = create(:github_push_event)

    expect(resource_client).to receive(:fetch).twice.and_return(github_resource_response({}, status: 500))

    enricher.enrich(push_event)

    expect(GithubActor.count).to eq(0)
    expect(GithubRepository.count).to eq(0)
    expect(push_event.reload.enriched_actor).to be_nil
    expect(push_event.enriched_repository).to be_nil
  end

  it "stops additional enrichment fetches after a rate limit response" do
    push_event = create(:github_push_event)

    expect(resource_client).to receive(:fetch)
      .once
      .and_return(github_resource_response({}, status: 403, rate_limit_remaining: 0))

    enricher.enrich(push_event)

    expect(push_event.reload.enriched_actor).to be_nil
    expect(push_event.enriched_repository).to be_nil
  end

  def github_resource_response(payload, status: 200, rate_limit_remaining: 60)
    Github::ResourceClient::Response.new(
      status:,
      payload:,
      rate_limit_remaining:,
      rate_limit_resets_at: 1.hour.from_now
    )
  end

  def actor_payload
    {
      "id" => 456,
      "login" => "contributor",
      "avatar_url" => "https://avatars.githubusercontent.com/u/456?",
      "html_url" => "https://github.com/contributor"
    }
  end

  def repository_payload
    {
      "id" => 12_345,
      "name" => "rails",
      "full_name" => "rails/rails",
      "html_url" => "https://github.com/rails/rails",
      "description" => "Ruby on Rails",
      "owner" => {
        "login" => "rails"
      }
    }
  end
end
