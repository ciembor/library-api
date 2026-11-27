require "rails_helper"

RSpec.describe "borrowing state transition serializers" do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }
  let(:borrowing) { Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days) }

  it "serializes borrowing timestamps" do
    expect(BorrowingTimestampsSerializer.new(borrowing).as_json).to eq(borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
  end

  it "serializes the return timestamp" do
    borrowing.update!(returned_at: borrowed_at + 1.day)

    expect(ReturnSerializer.new(borrowing).as_json).to eq(returned_at: borrowed_at + 1.day)
  end
end
