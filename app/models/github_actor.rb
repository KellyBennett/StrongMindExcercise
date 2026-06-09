class GithubActor < ApplicationRecord
  has_many :github_push_events, dependent: :nullify

  validates :github_id, presence: true, uniqueness: true
  validates :login, presence: true
  validates :raw_payload, presence: true
end
