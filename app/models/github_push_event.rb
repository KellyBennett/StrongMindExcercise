class GithubPushEvent < ApplicationRecord
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
end
