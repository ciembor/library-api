# Creates library-owned copies with six-digit serial numbers.
class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |table|
      table.integer :serial_number, null: false
      table.string :title, null: false
      table.string :author, null: false
      table.datetime :archived_at
      table.timestamps
    end
    add_index :books, :serial_number, unique: true
    add_check_constraint :books, "serial_number BETWEEN 100000 AND 999999", name: "books_serial_number_six_digits"
    add_check_constraint :books, "length(btrim(title)) > 0", name: "books_title_not_blank"
    add_check_constraint :books, "length(btrim(author)) > 0", name: "books_author_not_blank"
  end
end
