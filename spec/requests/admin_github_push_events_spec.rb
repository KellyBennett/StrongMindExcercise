require "rails_helper"

RSpec.describe "Admin GitHub push events", type: :request do
  it "renders enriched push event summaries on the index page" do
    actor = create(:github_actor, login: "contributor", avatar_url: "https://avatars.githubusercontent.com/u/456?")
    repository = create(:github_repository, full_name: "rails/rails", html_url: "https://github.com/rails/rails")
    create(
      :github_push_event,
      actor_id: actor.github_id,
      actor_login: actor.login,
      github_repository_id: repository.github_id,
      repository_name: repository.full_name,
      enriched_actor: actor,
      enriched_repository: repository
    )

    get "/admin/github_push_events"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("contributor")
    expect(response.body).to include("https://avatars.githubusercontent.com/u/456?")
    expect(response.body).to include("rails/rails")
    expect(response.body).to include("compare push")
    expect(response.body).to include("enriched")
  end
end
