require "rails_helper"

RSpec.describe ReminderDelivery do
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowed_at) { Time.utc(2026, 11, 27, 12) }
  let(:borrowing) { Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days) }

  def delivery(kind = "three_days_before")
    described_class.new(borrowing: borrowing, kind: kind)
  end

  it "persists and logs a payload while locking the book" do
    allow(Rails.logger).to receive(:info)
    expect(Book).to receive(:lock).and_call_original

    reminder = delivery.deliver

    expect(reminder).to have_attributes(borrowing: borrowing, kind: "three_days_before", sent_at: be_present)
    expect(Rails.logger).to have_received(:info).with(reminder.payload.to_json)
  end

  it "does not prepare a reminder after the borrowing has been returned" do
    borrowing.update!(returned_at: borrowed_at + 1.day)
    expect(Rails.logger).not_to receive(:info)

    expect(delivery.deliver).to be_nil
    expect(BorrowingReminder.where(borrowing: borrowing)).to be_empty
  end

  it "does not log a duplicate reminder" do
    allow(Rails.logger).to receive(:info)
    delivery("due_date").deliver

    expect(delivery("due_date").deliver).to be_nil
    expect(Rails.logger).to have_received(:info).with(a_string_including("\"kind\":\"due_date\"")).once
  end

  it "keeps the persisted payload when logging fails" do
    allow(Rails.logger).to receive(:info).and_raise(Logger::Error, "logger unavailable")

    expect { delivery.deliver }.to raise_error(Logger::Error, "logger unavailable")
    expect(BorrowingReminder.where(borrowing: borrowing, kind: "three_days_before")).to exist
  end
end
