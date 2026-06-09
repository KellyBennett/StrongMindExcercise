class GithubIngestionCursor < ApplicationRecord
  PUBLIC_EVENTS = "public_events"

  validates :name, presence: true, uniqueness: true

  def self.public_events
    find_or_create_by!(name: PUBLIC_EVENTS)
  end

  def polling_paused?(now: Time.current)
    next_poll_at.present? && next_poll_at > now
  end

  def rate_limited?(now: Time.current)
    rate_limit_remaining.to_i <= 0 && rate_limit_resets_at.present? && rate_limit_resets_at > now
  end

  def polling_available?(now: Time.current)
    !polling_paused?(now:) && !rate_limited?(now:)
  end
end
