require "administrate/base_dashboard"

class GithubRepositoryDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    github_id: Field::Number,
    name: Field::String,
    full_name: Field::String,
    html_url: Field::String,
    description: Field::Text,
    owner_login: Field::String,
    raw_payload: Field::String.with_options(searchable: false),
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    github_push_events: Field::HasMany
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    github_id
    full_name
    owner_login
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    github_id
    name
    full_name
    html_url
    description
    owner_login
    raw_payload
    github_push_events
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    github_id
    name
    full_name
    html_url
    description
    owner_login
    raw_payload
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(github_repository)
    github_repository.full_name.presence || github_repository.name
  end
end
