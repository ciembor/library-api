require "rails_helper"

RSpec.describe "library database integrity" do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }

  def reject_insert(model, attributes)
    expect do
      ActiveRecord::Base.transaction(requires_new: true) { model.insert_all!([ attributes ]) }
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "enforces book number, required text, and uniqueness without model validations" do
    reject_insert(Book, serial_number: 99_999, title: "Dune", author: "Frank Herbert")
    reject_insert(Book, serial_number: 1_000_000, title: "Dune", author: "Frank Herbert")
    reject_insert(Book, serial_number: 222_222, title: " ", author: "Frank Herbert")
    reject_insert(Book, serial_number: 222_222, title: "Dune", author: " ")
    reject_insert(Book, serial_number: 222_222, title: "Dune")

    book
    reject_insert(Book, serial_number: 123_456, title: "Duplicate", author: "Someone")
  end

  it "enforces reader number, required data, and case-insensitive email uniqueness" do
    reject_insert(Reader, library_card_number: 99_999, full_name: "Ada", email: "ada@example.com")
    reject_insert(Reader, library_card_number: 1_000_000, full_name: "Ada", email: "ada@example.com")
    reject_insert(Reader, library_card_number: 222_222, full_name: " ", email: "ada@example.com")
    reject_insert(Reader, library_card_number: 222_222, full_name: "Ada", email: " ")
    reject_insert(Reader, library_card_number: 222_222, full_name: "Ada")

    reader
    reject_insert(Reader, library_card_number: 654_321, full_name: "Grace", email: "grace@example.com")
    reject_insert(Reader, library_card_number: 222_222, full_name: "Grace", email: "ADA@example.com")
  end

  it "enforces borrowing foreign keys, dates, and one active borrowing per book" do
    valid = { book_id: book.id, reader_id: reader.id, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days }

    reject_insert(Borrowing, valid.merge(book_id: -1))
    reject_insert(Borrowing, valid.merge(reader_id: -1))
    reject_insert(Borrowing, valid.except(:borrowed_at))
    reject_insert(Borrowing, valid.except(:due_at))
    reject_insert(Borrowing, valid.merge(due_at: borrowed_at + 29.days))
    reject_insert(Borrowing, valid.merge(returned_at: borrowed_at - 1.second))

    Borrowing.insert_all!([ valid ])
    reject_insert(Borrowing, valid)

    Borrowing.first.update!(returned_at: borrowed_at + 1.day)
    Borrowing.insert_all!([ valid ])
    expect(Borrowing.where(book: book).count).to eq(2)
  end
end
