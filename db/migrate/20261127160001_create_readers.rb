# Creates readers with unique card numbers and case-insensitive email uniqueness.
class CreateReaders < ActiveRecord::Migration[8.1]
  def change
    create_table :readers do |table|
      table.integer :library_card_number, null: false
      table.string :full_name, null: false
      table.string :email, null: false
      table.timestamps
    end
    add_index :readers, :library_card_number, unique: true
    add_index :readers, "lower(email)", unique: true, name: "index_readers_on_lower_email"
    add_check_constraint :readers, "library_card_number BETWEEN 100000 AND 999999", name: "readers_card_number_six_digits"
    add_check_constraint :readers, "length(btrim(full_name)) > 0", name: "readers_full_name_not_blank"
    add_check_constraint :readers, "length(btrim(email)) > 0", name: "readers_email_not_blank"
  end
end
