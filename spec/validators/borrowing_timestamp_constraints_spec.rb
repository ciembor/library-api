require "rails_helper"

RSpec.describe BorrowingTimestampConstraints, "#validate", mutant_expression: "BorrowingTimestampConstraints#validate" do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }

  def borrowing(attributes = {})
    Borrowing.new({ book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days }.merge(attributes))
  end

  it "adds errors for both timestamp invariants", mutant_expression: "BorrowingTimestampConstraints#validate" do
    record = borrowing(due_at: borrowed_at + 29.days, returned_at: borrowed_at - 1.second)

    described_class.new(record, borrowing_period: 30.days).validate

    expect(record.errors.to_hash).to include(due_at: [ "must be 30 days after borrowing" ], returned_at: [ "must be after borrowing" ])
  end

  it "accepts blank optional timestamps and valid dates", mutant_expression: "BorrowingTimestampConstraints#validate" do
    record = borrowing

    described_class.new(record, borrowing_period: 30.days).validate

    expect(record.errors).to be_empty
  end
end
