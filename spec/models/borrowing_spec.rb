require "rails_helper"

RSpec.describe Borrowing do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }

  it "requires both book and reader" do
    borrowing = described_class.new(borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
    expect(borrowing).not_to be_valid
    expect(borrowing.errors.attribute_names).to include(:book, :reader)
  end

  it "requires borrow and due timestamps" do
    without_borrow_date = described_class.new(book: book, reader: reader, due_at: borrowed_at + 30.days, returned_at: borrowed_at + 1.day)
    expect(without_borrow_date).not_to be_valid
    expect(without_borrow_date.errors[:borrowed_at]).to eq([ "can't be blank" ])
    expect(without_borrow_date.errors[:returned_at]).to be_empty

    without_due_date = described_class.new(book: book, reader: reader, borrowed_at: borrowed_at)
    expect(without_due_date).not_to be_valid
    expect(without_due_date.errors[:due_at]).to eq([ "can't be blank" ])
  end

  it "accepts exactly 30 days and a return after borrowing" do
    borrowing = described_class.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
    expect(borrowing).to be_valid
    borrowing.returned_at = borrowed_at + 1.day
    expect(borrowing).to be_valid
  end

  it "rejects a due date other than 30 days after borrowing" do
    borrowing = described_class.new(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 29.days)
    expect(borrowing).not_to be_valid
    expect(borrowing.errors[:due_at]).to include("must be 30 days after borrowing")
  end

  it "rejects a return before borrowing" do
    borrowing = described_class.new(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days, returned_at: borrowed_at - 1.second)
    expect(borrowing).not_to be_valid
    expect(borrowing.errors[:returned_at]).to include("must be after borrowing")
  end
end
