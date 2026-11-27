# Stores durable reminder payloads and makes each reminder kind idempotent.
class CreateBorrowingReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowing_reminders do |table|
      table.references :borrowing, null: false, foreign_key: true
      table.string :kind, null: false
      table.jsonb :payload, null: false
      table.datetime :sent_at, null: false
      table.timestamps
    end
    add_index :borrowing_reminders, %i[borrowing_id kind], unique: true
    add_check_constraint :borrowing_reminders, "kind IN ('three_days_before', 'due_date')", name: "borrowing_reminders_kind"
  end
end
