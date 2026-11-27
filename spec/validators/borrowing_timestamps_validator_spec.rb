require "rails_helper"

RSpec.describe BorrowingTimestampsValidator, "#validate", mutant_expression: "BorrowingTimestampsValidator#validate" do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }

  def borrowing(attributes = {})
    Borrowing.new({ book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days }.merge(attributes))
  end

  it "adds errors for both timestamp invariants", mutant_expression: "BorrowingTimestampsValidator#validate" do
    record = borrowing(due_at: borrowed_at + 29.days, returned_at: borrowed_at - 1.second)

    described_class.new.validate(record)

    expect(record.errors.to_hash).to include(due_at: [ "must be 30 days after borrowing" ], returned_at: [ "must be on or after borrowing" ])
  end

  it "uses its configured borrowing period", mutant_expression: "BorrowingTimestampsValidator#validate" do
    record = borrowing(due_at: borrowed_at + 14.days)

    described_class.new(borrowing_period: 14.days).validate(record)

    expect(record.errors).to be_empty
  end

  it "uses a 30 day borrowing period by default", mutant_expression: "BorrowingTimestampsValidator#validate" do
    record = borrowing

    described_class.new.validate(record)

    expect(record.errors).to be_empty
  end
end
