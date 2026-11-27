require "rails_helper"

RSpec.describe EnqueuePendingBorrowingRemindersJob do
  include ActiveJob::TestHelper

  it "enqueues durable reminder schedules left pending by a prior failure" do
    book = Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert")
    reader = Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com")
    due_at = Time.utc(2026, 12, 27, 12)
    borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: due_at - 30.days, due_at: due_at)
    BorrowingReminderScheduler.new(borrowing).prepare

    described_class.perform_now

    expect(borrowing.reminder_schedules.pending).to be_empty
    expect(enqueued_jobs.filter_map { |job| job[:args].second if job[:job] == SendBorrowingReminderJob }).to contain_exactly("three_days_before", "due_date")
  end
end
