class GithubPushEvent < ApplicationRecord
  validates :github_event_id, presence: true, uniqueness: true
  validates :github_repository_id, presence: true
  validates :repository_name, presence: true
  validates :push_identifier, presence: true, uniqueness: true
  validates :ref, presence: true
  validates :head, presence: true
  validates :before, presence: true
  validates :raw_payload, presence: true
end
