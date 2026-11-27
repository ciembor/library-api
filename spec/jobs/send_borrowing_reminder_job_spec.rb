require "rails_helper"

RSpec.describe SendBorrowingReminderJob do
  include ActiveSupport::Testing::TimeHelpers

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
      "reader" => { "library_card_number" => reader.library_card_number, "full_name" => reader.full_name, "email" => reader.email },
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

  it "delivers one durable payload for each scheduled reminder time" do
    travel_to(borrowing.due_at - 72.hours) { perform("three_days_before") }
    travel_to(borrowing.due_at) { perform("due_date") }

    expect(BorrowingReminder.where(borrowing: borrowing)).to contain_exactly(
      have_attributes(kind: "three_days_before", sent_at: borrowing.due_at - 72.hours, payload: include("kind" => "three_days_before")),
      have_attributes(kind: "due_date", sent_at: borrowing.due_at, payload: include("kind" => "due_date"))
    )
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

  it "does not send the due-date reminder after a return between both reminder times" do
    perform("three_days_before")
    borrowing.update!(returned_at: borrowed_at + 28.days)

    perform("due_date")

    expect(BorrowingReminder.where(borrowing: borrowing).pluck(:kind)).to eq([ "three_days_before" ])
  end

  it "does not apply a stale job to a later borrowing of the same book" do
    previous_borrowing = borrowing
    previous_borrowing.update!(returned_at: borrowed_at + 1.day)
    next_borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at + 2.days, due_at: borrowed_at + 32.days)

    described_class.perform_now(previous_borrowing.id, "due_date")

    expect(BorrowingReminder.where(borrowing: previous_borrowing)).to be_empty
    expect(BorrowingReminder.where(borrowing: next_borrowing)).to be_empty
  end
end
