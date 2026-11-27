require "rails_helper"

RSpec.describe BorrowBook do
  include ActiveJob::TestHelper

  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }

  def operation(serial_number: book.serial_number, library_card_number: reader.library_card_number)
    described_class.new(serial_number: serial_number, library_card_number: library_card_number, borrowed_at: borrowed_at)
  end

  it "creates a borrowing with a 30-day due date while locking the book" do
    expect(Book).to receive(:lock).and_call_original

    borrowing = operation.call

    expect(borrowing).to have_attributes(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days, returned_at: nil)
  end

  it "schedules both reminders after creating a borrowing" do
    clear_enqueued_jobs

    borrowing = operation.call
    jobs = enqueued_jobs.select { |job| job[:job] == SendBorrowingReminderJob }

    expect(jobs).to contain_exactly(
      include(args: [ borrowing.id, "three_days_before" ], at: (borrowed_at + 27.days).to_f),
      include(args: [ borrowing.id, "due_date" ], at: (borrowed_at + 30.days).to_f)
    )
  end

  it "keeps durable pending schedules when immediate enqueue fails" do
    allow(SendBorrowingReminderJob).to receive(:set).and_raise(ActiveJob::EnqueueError, "queue unavailable")
    allow(Rails.logger).to receive(:error)

    borrowing = operation.call

    expect(borrowing.reminder_schedules.pending).to contain_exactly(
      have_attributes(kind: "three_days_before"),
      have_attributes(kind: "due_date")
    )
    expect(Rails.logger).to have_received(:error).with(include("Reminder scheduling failed for borrowing #{borrowing.id}"))
  end

  it "raises not found when the reader does not exist" do
    expect { operation(library_card_number: 999_999).call }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "raises not found when the book does not exist" do
    expect { operation(serial_number: 999_999).call }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "rejects an archived book" do
    book.update!(archived_at: borrowed_at)

    expect { operation.call }.to raise_error(BorrowingConflict, "An archived book cannot be borrowed.")
  end

  it "rejects a book with an active borrowing" do
    Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)

    expect { operation.call }.to raise_error(BorrowingConflict, "The book is already borrowed.")
  end

  it "translates a uniqueness race into a conflict" do
    allow(Borrowing).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

    expect { operation.call }.to raise_error(BorrowingConflict, "The book is already borrowed.")
  end
end
