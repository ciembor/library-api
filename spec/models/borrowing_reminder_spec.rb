require "rails_helper"

RSpec.describe BorrowingReminder do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowing) { Borrowing.create!(book: book, reader: reader, borrowed_at: Time.utc(2026, 11, 27), due_at: Time.utc(2026, 12, 27)) }

  it "accepts a supported kind with a payload and send time" do
    reminder = described_class.new(borrowing: borrowing, kind: "due_date", payload: { "to" => reader.email }, sent_at: Time.current)

    expect(reminder).to be_valid
  end

  it "requires a supported kind, payload, and send time" do
    reminder = described_class.new(borrowing: borrowing, kind: "unknown")

    expect(reminder).not_to be_valid
    expect(reminder.errors.attribute_names).to contain_exactly(:kind, :payload, :sent_at)
  end
end
