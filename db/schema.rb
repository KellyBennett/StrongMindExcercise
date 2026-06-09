# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_09_001000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "github_ingestion_cursors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "etag"
    t.string "name", null: false
    t.datetime "next_poll_at"
    t.integer "rate_limit_remaining"
    t.datetime "rate_limit_resets_at"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_github_ingestion_cursors_on_name", unique: true
  end

  create_table "github_push_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_login"
    t.string "before", null: false
    t.datetime "created_at", null: false
    t.string "github_event_id", null: false
    t.bigint "github_repository_id", null: false
    t.string "head", null: false
    t.bigint "push_identifier", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.string "ref", null: false
    t.string "repository_name", null: false
    t.datetime "updated_at", null: false
    t.index ["github_event_id"], name: "index_github_push_events_on_github_event_id", unique: true
    t.index ["github_repository_id"], name: "index_github_push_events_on_github_repository_id"
    t.index ["push_identifier"], name: "index_github_push_events_on_push_identifier", unique: true
  end
end
