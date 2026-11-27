# Stores the loan history and restricts each book to one active loan.
class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings do |table|
      table.references :book, null: false, foreign_key: true
      table.references :reader, null: false, foreign_key: true
      table.datetime :borrowed_at, null: false
      table.datetime :due_at, null: false
      table.datetime :returned_at
      table.timestamps
    end
    add_index :borrowings, :book_id, unique: true, where: "returned_at IS NULL", name: "index_borrowings_on_active_book"
    add_check_constraint :borrowings, "due_at = borrowed_at + interval '30 days'", name: "borrowings_due_after_30_days"
    add_check_constraint :borrowings, "returned_at IS NULL OR returned_at >= borrowed_at", name: "borrowings_return_after_borrow"
  end
end
