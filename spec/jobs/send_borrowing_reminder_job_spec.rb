require "rails_helper"

RSpec.describe SendBorrowingReminderJob do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }
  let(:borrowing) { Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days) }

  def perform(kind = "three_days_before")
    described_class.perform_now(borrowing.id, kind)
  end

  it "persists and logs a complete three-day reminder payload" do
    allow(Rails.logger).to receive(:info)

    perform

    reminder = BorrowingReminder.find_by!(borrowing: borrowing, kind: "three_days_before")
    expect(Rails.logger).to have_received(:info).with(a_string_including(reader.email, "three_days_before"))
    expect(reminder.payload).to include(
      "to" => reader.email,
      "subject" => "Library book due in 3 days",
      "reader" => ReaderSerializer.new(reader).as_json.stringify_keys,
      "book" => { "serial_number" => book.serial_number, "title" => book.title },
      "due_at" => borrowing.due_at.iso8601,
      "kind" => "three_days_before"
    )
    expect(reminder.payload.fetch("body")).to include(reader.full_name, book.title, book.serial_number.to_s)
  end

  it "persists only one reminder when the job is retried" do
    perform("due_date")
    perform("due_date")

    expect(BorrowingReminder.where(borrowing: borrowing, kind: "due_date")).to contain_exactly(have_attributes(payload: include("subject" => "Library book due today")))
  end

  it "skips a returned borrowing" do
    borrowing.update!(returned_at: borrowed_at + 1.day)
    expect(ReminderDelivery).not_to receive(:new)

    perform

    expect(BorrowingReminder.where(borrowing: borrowing)).to be_empty
  end

  it "skips a borrowing that no longer exists" do
    borrowing.destroy!
    expect(ReminderDelivery).not_to receive(:new)

    described_class.perform_now(borrowing.id, "due_date")
  end
end
