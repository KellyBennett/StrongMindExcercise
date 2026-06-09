FactoryBot.define do
  factory :github_actor do
    sequence(:github_id) { |n| 400_000 + n }
    login { "contributor" }
    avatar_url { "https://avatars.githubusercontent.com/u/#{github_id}?" }
    html_url { "https://github.com/#{login}" }
    raw_payload do
      {
        "id" => github_id,
        "login" => login,
        "avatar_url" => avatar_url,
        "html_url" => html_url
      }
    end
  end
end
