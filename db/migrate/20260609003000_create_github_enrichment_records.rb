class CreateGithubEnrichmentRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :github_actors do |t|
      t.bigint :github_id, null: false
      t.string :login, null: false
      t.string :avatar_url
      t.string :html_url
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :github_actors, :github_id, unique: true
    add_index :github_actors, :login

    create_table :github_repositories do |t|
      t.bigint :github_id, null: false
      t.string :name, null: false
      t.string :full_name
      t.string :html_url
      t.text :description
      t.string :owner_login
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :github_repositories, :github_id, unique: true
    add_index :github_repositories, :full_name
    add_index :github_repositories, :owner_login

    change_table :github_push_events do |t|
      t.references :github_actor, foreign_key: true
      t.references :github_repository_record, foreign_key: { to_table: :github_repositories }
    end
  end
end
