require "rails_helper"

RSpec.describe BookSerializer do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }

  it "serializes catalog fields and availability" do
    expect(described_class.new(book).as_json).to eq(serial_number: 123_456, title: "Dune", author: "Frank Herbert", status: "available")
  end

  it "serializes borrowing history with reader data" do
    borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)

    expect(described_class.new(book, borrowings: [ borrowing ]).as_json).to include(
      borrowings: [ include(borrowed_at: borrowed_at, due_at: borrowed_at + 30.days, returned_at: nil, reader: ReaderSerializer.new(reader).as_json) ]
    )
  end
end
