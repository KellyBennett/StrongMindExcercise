FactoryBot.define do
  factory :github_ingestion_cursor do
    name { GithubIngestionCursor::PUBLIC_EVENTS }

    trait :waiting_for_next_poll do
      next_poll_at { 5.minutes.from_now }
    end

    trait :rate_limited do
      rate_limit_remaining { 0 }
      rate_limit_resets_at { 20.minutes.from_now }
    end

    trait :with_etag do
      etag { "previous-etag" }
    end
  end
end
