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

  it "continues recovery after an individual schedule cannot be enqueued" do
    book = Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert")
    reader = Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com")
    first_borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: Time.utc(2026, 11, 27), due_at: Time.utc(2026, 12, 27))
    second_book = Book.create!(serial_number: 123_457, title: "Foundation", author: "Isaac Asimov")
    second_borrowing = Borrowing.create!(book: second_book, reader: reader, borrowed_at: Time.utc(2026, 11, 27), due_at: Time.utc(2026, 12, 27))
    BorrowingReminderScheduler.new(first_borrowing).prepare
    BorrowingReminderScheduler.new(second_borrowing).prepare
    failed_schedule = first_borrowing.reminder_schedules.find_by!(kind: "three_days_before")

    allow_any_instance_of(BorrowingReminderSchedule).to receive(:enqueue).and_wrap_original do |method, job_class|
      raise ActiveJob::EnqueueError, "queue unavailable" if method.receiver.id == failed_schedule.id

      method.call(job_class)
    end

    described_class.perform_now

    expect(failed_schedule.reload.enqueued_at).to be_nil
    expect(first_borrowing.reminder_schedules.pending.count).to eq(1)
    expect(second_borrowing.reminder_schedules.pending).to be_empty
  end
end
