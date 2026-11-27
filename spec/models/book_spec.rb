require "rails_helper"

RSpec.describe Book do
  let(:book) { described_class.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }

  it "accepts a six-digit serial number and required text" do
    expect(book).to be_valid
    expect(described_class.new(serial_number: 99_999, title: "Dune", author: "Frank Herbert")).not_to be_valid
    expect(described_class.new(serial_number: 1_000_000, title: "Dune", author: "Frank Herbert")).not_to be_valid
    expect(described_class.new(serial_number: 123_456, title: " ", author: "Frank Herbert")).not_to be_valid
    expect(described_class.new(serial_number: 123_456, title: "Dune", author: " ")).not_to be_valid
  end

  it "rejects a duplicate serial number" do
    book
    expect(described_class.new(serial_number: 123_456, title: "Another", author: "Someone")).not_to be_valid
  end

  it "derives availability from the active borrowing" do
    expect(book.status).to eq("available")

    borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: Time.utc(2026, 11, 27), due_at: Time.utc(2026, 12, 27))
    expect(book.reload.status).to eq("borrowed")

    borrowing.update!(returned_at: Time.utc(2026, 11, 28))
    expect(book.reload.status).to eq("available")
    expect(described_class.column_names).not_to include("status")
  end
end
