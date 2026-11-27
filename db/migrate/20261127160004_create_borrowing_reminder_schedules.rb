# Stores reminder jobs that still need to be enqueued.
class CreateBorrowingReminderSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowing_reminder_schedules do |t|
      t.references :borrowing, null: false, foreign_key: true
      t.string :kind, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :enqueued_at

      t.timestamps
    end

    add_index :borrowing_reminder_schedules, [ :borrowing_id, :kind ], unique: true
  end
end
