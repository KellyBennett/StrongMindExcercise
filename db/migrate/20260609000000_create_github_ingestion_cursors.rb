class CreateGithubIngestionCursors < ActiveRecord::Migration[8.1]
  def change
    create_table :github_ingestion_cursors do |t|
      t.string :name, null: false
      t.string :etag
      t.datetime :next_poll_at
      t.integer :rate_limit_remaining
      t.datetime :rate_limit_resets_at

      t.timestamps
    end

    add_index :github_ingestion_cursors, :name, unique: true
  end
end
