# frozen_string_literal: true

class UseExactBorrowingDuration < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :borrowings, name: "borrowings_due_after_30_days"
    add_check_constraint :borrowings, "due_at = borrowed_at + interval '720 hours'", name: "borrowings_due_after_30_days"
  end
end
