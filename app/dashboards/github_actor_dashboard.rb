require "administrate/base_dashboard"

class GithubActorDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    github_id: Field::Number,
    login: Field::String,
    avatar_url: Field::String,
    html_url: Field::String,
    raw_payload: Field::String.with_options(searchable: false),
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    github_push_events: Field::HasMany
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    github_id
    login
    html_url
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    github_id
    login
    avatar_url
    html_url
    raw_payload
    github_push_events
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    github_id
    login
    avatar_url
    html_url
    raw_payload
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(github_actor)
    github_actor.login
  end
end
