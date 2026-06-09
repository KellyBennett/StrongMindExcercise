FactoryBot.define do
  factory :github_push_event do
    sequence(:github_event_id) { |n| "event-#{n}" }
    sequence(:github_repository_id) { |n| 100_000 + n }
    repository_name { "rails/rails" }
    sequence(:push_identifier) { |n| 200_000 + n }
    ref { "refs/heads/main" }
    head { "HEAD_SHA" }
    add_attribute(:before) { "BEFORE_SHA" }
    actor_id { 300_000 }
    actor_login { "contributor" }
    raw_payload do
      {
        "id" => github_event_id,
        "type" => "PushEvent",
        "repo" => {
          "id" => github_repository_id,
          "name" => repository_name
        },
        "actor" => {
          "id" => actor_id,
          "login" => actor_login
        },
        "payload" => {
          "push_id" => push_identifier,
          "ref" => ref,
          "head" => head,
          "before" => before
        }
      }
    end
  end
end
