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

ActiveRecord::Schema[8.1].define(version: 2026_11_27_160003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "books", force: :cascade do |t|
    t.integer "serial_number", null: false
    t.string "title", null: false
    t.string "author", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["serial_number"], name: "index_books_on_serial_number", unique: true
    t.check_constraint "length(btrim(author::text)) > 0", name: "books_author_not_blank"
    t.check_constraint "length(btrim(title::text)) > 0", name: "books_title_not_blank"
    t.check_constraint "serial_number >= 100000 AND serial_number <= 999999", name: "books_serial_number_six_digits"
  end

  create_table "borrowing_reminders", force: :cascade do |t|
    t.bigint "borrowing_id", null: false
    t.string "kind", null: false
    t.jsonb "payload", null: false
    t.datetime "sent_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["borrowing_id", "kind"], name: "index_borrowing_reminders_on_borrowing_id_and_kind", unique: true
    t.index ["borrowing_id"], name: "index_borrowing_reminders_on_borrowing_id"
    t.check_constraint "kind::text = ANY (ARRAY['three_days_before'::character varying, 'due_date'::character varying]::text[])", name: "borrowing_reminders_kind"
  end

  create_table "borrowings", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.bigint "reader_id", null: false
    t.datetime "borrowed_at", null: false
    t.datetime "due_at", null: false
    t.datetime "returned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_borrowings_on_active_book", unique: true, where: "(returned_at IS NULL)"
    t.index ["book_id"], name: "index_borrowings_on_book_id"
    t.index ["reader_id"], name: "index_borrowings_on_reader_id"
    t.check_constraint "due_at = (borrowed_at + 'P30D'::interval)", name: "borrowings_due_after_30_days"
    t.check_constraint "returned_at IS NULL OR returned_at >= borrowed_at", name: "borrowings_return_after_borrow"
  end

  create_table "readers", force: :cascade do |t|
    t.integer "library_card_number", null: false
    t.string "full_name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_readers_on_lower_email", unique: true
    t.index ["library_card_number"], name: "index_readers_on_library_card_number", unique: true
    t.check_constraint "length(btrim(email::text)) > 0", name: "readers_email_not_blank"
    t.check_constraint "length(btrim(full_name::text)) > 0", name: "readers_full_name_not_blank"
    t.check_constraint "library_card_number >= 100000 AND library_card_number <= 999999", name: "readers_card_number_six_digits"
  end

  add_foreign_key "borrowing_reminders", "borrowings"
  add_foreign_key "borrowings", "books"
  add_foreign_key "borrowings", "readers"
end
