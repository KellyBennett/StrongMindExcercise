class CreateGithubPushEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :github_push_events do |t|
      t.string :github_event_id, null: false
      t.bigint :github_repository_id, null: false
      t.string :repository_name, null: false
      t.bigint :push_identifier, null: false
      t.string :ref, null: false
      t.string :head, null: false
      t.string :before, null: false
      t.bigint :actor_id
      t.string :actor_login
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :github_push_events, :github_event_id, unique: true
    add_index :github_push_events, :github_repository_id
    add_index :github_push_events, :push_identifier, unique: true
  end
end
