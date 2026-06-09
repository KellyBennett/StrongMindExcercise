require "rails_helper"

RSpec.describe GithubPushEvent, type: :model do
  it "stores required query fields as structured database columns" do
    required_columns = {
      "github_repository_id" => :integer,
      "push_identifier" => :integer,
      "ref" => :string,
      "head" => :string,
      "before" => :string
    }

    required_columns.each do |column_name, column_type|
      expect(described_class.columns_hash[column_name].type).to eq(column_type)
    end
  end

  it "can query required structured fields without inspecting raw payload JSON" do
    matching_event = create(
      :github_push_event,
      github_repository_id: 12_345,
      push_identifier: 67_890,
      ref: "refs/heads/main",
      head: "HEAD_SHA",
      before: "BEFORE_SHA"
    )
    create(:github_push_event)

    result = described_class.find_by!(
      github_repository_id: 12_345,
      push_identifier: 67_890,
      ref: "refs/heads/main",
      head: "HEAD_SHA",
      before: "BEFORE_SHA"
    )

    expect(result).to eq(matching_event)
  end
end
