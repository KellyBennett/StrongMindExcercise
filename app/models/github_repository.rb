class GithubRepository < ApplicationRecord
  has_many :github_push_events, foreign_key: :github_repository_record_id, dependent: :nullify

  validates :github_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :raw_payload, presence: true
end
