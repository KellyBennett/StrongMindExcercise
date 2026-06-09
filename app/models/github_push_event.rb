class GithubPushEvent < ApplicationRecord
  has_one_attached :raw_event_payload

  belongs_to :enriched_actor, class_name: "GithubActor", foreign_key: :github_actor_id, optional: true
  belongs_to :enriched_repository,
    class_name: "GithubRepository",
    foreign_key: :github_repository_record_id,
    optional: true

  validates :github_event_id, presence: true, uniqueness: true
  validates :github_repository_id, presence: true
  validates :repository_name, presence: true
  validates :push_identifier, presence: true, uniqueness: true
  validates :ref, presence: true
  validates :head, presence: true
  validates :before, presence: true
  validates :raw_payload, presence: true

  def event_summary
    self
  end

  def display_actor_login
    enriched_actor&.login.presence || actor_login.presence || "unknown"
  end

  def actor_avatar_url
    enriched_actor&.avatar_url.presence || raw_payload.dig("actor", "avatar_url")
  end

  def actor_html_url
    enriched_actor&.html_url.presence || github_url_for(display_actor_login)
  end

  def repository_html_url
    enriched_repository&.html_url.presence || github_url_for(repository_name)
  end

  def branch_name
    ref.delete_prefix("refs/heads/")
  end

  def ref_label
    branch_ref? ? branch_name : ref
  end

  def ref_html_url
    return unless branch_ref? && repository_html_url.present?

    "#{repository_html_url}/tree/#{branch_name}"
  end

  def commit_html_url
    return if repository_html_url.blank?

    "#{repository_html_url}/commit/#{head}"
  end

  def push_html_url
    return if repository_html_url.blank?

    "#{repository_html_url}/compare/#{before}...#{head}"
  end

  def short_head
    head.first(7)
  end

  def enriched?
    enriched_actor.present? || enriched_repository.present?
  end

  private

  def branch_ref?
    ref.start_with?("refs/heads/")
  end

  def github_url_for(path)
    return if path.blank? || path == "unknown"

    "https://github.com/#{path}"
  end
end
