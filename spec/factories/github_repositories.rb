FactoryBot.define do
  factory :github_repository do
    sequence(:github_id) { |n| 500_000 + n }
    name { "rails" }
    full_name { "rails/rails" }
    html_url { "https://github.com/#{full_name}" }
    description { "Ruby on Rails" }
    owner_login { "rails" }
    raw_payload do
      {
        "id" => github_id,
        "name" => name,
        "full_name" => full_name,
        "html_url" => html_url,
        "description" => description,
        "owner" => {
          "login" => owner_login
        }
      }
    end
  end
end
