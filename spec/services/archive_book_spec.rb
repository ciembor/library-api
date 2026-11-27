require "rails_helper"

RSpec.describe ArchiveBook do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:archived_at) { Time.utc(2026, 11, 27, 12) }

  def operation(serial_number: book.serial_number)
    described_class.new(serial_number: serial_number, archived_at: archived_at)
  end

  it "archives an available book while locking it" do
    expect(Book).to receive(:lock).and_call_original

    expect(operation.call).to have_attributes(id: book.id, archived_at: archived_at)
  end

  it "does not replace an existing archive timestamp" do
    book.update!(archived_at: archived_at - 1.day)

    expect(operation.call.archived_at).to eq(archived_at - 1.day)
  end

  it "rejects an actively borrowed book" do
    Borrowing.create!(book: book, reader: reader, borrowed_at: archived_at, due_at: archived_at + 30.days)

    expect { operation.call }.to raise_error(BorrowingConflict, "A borrowed book cannot be archived.")
  end

  it "raises not found for an unknown book" do
    expect { operation(serial_number: 999_999).call }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
