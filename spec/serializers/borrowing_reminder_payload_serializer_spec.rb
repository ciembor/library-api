require "rails_helper"

RSpec.describe BorrowingReminderPayloadSerializer do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }
  let(:borrowing) { Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days) }

  it "serializes the complete due-date reminder payload" do
    expect(described_class.new(borrowing, "due_date").as_json).to include(
      to: reader.email,
      subject: "Library book due today",
      reader: { library_card_number: reader.library_card_number, full_name: reader.full_name, email: reader.email },
      book: { serial_number: book.serial_number, title: book.title },
      due_at: borrowing.due_at.iso8601,
      kind: "due_date"
    )
  end
end
