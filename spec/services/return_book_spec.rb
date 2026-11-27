require "rails_helper"

RSpec.describe ReturnBook do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }
  let(:returned_at) { borrowed_at + 2.days }

  def operation(serial_number: book.serial_number)
    described_class.new(serial_number: serial_number, returned_at: returned_at)
  end

  it "returns the active borrowing while locking the book" do
    borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
    expect(Book).to receive(:lock).and_call_original

    result = operation.call

    expect(result).to eq(borrowing)
    expect(borrowing.reload.returned_at).to eq(returned_at)
  end

  it "raises not found when the book does not exist" do
    expect { operation(serial_number: 999_999).call }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "rejects a book without an active borrowing" do
    expect { operation.call }.to raise_error(BorrowingConflict, "The book is already available.")
  end

  it "rolls back the return when closing the borrowing fails" do
    borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
    allow_any_instance_of(Borrowing).to receive(:update!) do |loan, attributes|
      loan.update_column(:returned_at, attributes[:returned_at])
      raise ActiveRecord::RecordInvalid, loan
    end

    expect { operation.call }.to raise_error(ActiveRecord::RecordInvalid)
    expect(borrowing.reload.returned_at).to be_nil
  end
end
