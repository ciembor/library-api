require "rails_helper"

RSpec.describe BorrowingReminderScheduler do
  include ActiveJob::TestHelper

  let(:due_at) { Time.utc(2026, 12, 27, 12) }
  let(:book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:borrowing) { Borrowing.create!(book: book, reader: reader, borrowed_at: due_at - 30.days, due_at: due_at) }

  it "durably prepares and schedules each reminder at its exact due-date offset" do
    described_class.new(borrowing).prepare
    described_class.new(borrowing).schedule

    expect(borrowing.reminder_schedules).to contain_exactly(
      have_attributes(kind: "three_days_before", scheduled_at: due_at - 3.days, enqueued_at: be_present),
      have_attributes(kind: "due_date", scheduled_at: due_at, enqueued_at: be_present)
    )
    expect(enqueued_jobs.filter_map { |job| job[:args].second if job[:job] == SendBorrowingReminderJob }).to contain_exactly("three_days_before", "due_date")
  end

  it "retries only the reminder left pending by an enqueue failure" do
    described_class.new(borrowing).prepare
    failed_once = true
    allow(SendBorrowingReminderJob).to receive(:set).and_wrap_original do |method, wait_until:|
      if wait_until == due_at && failed_once
        failed_once = false
        raise ActiveJob::EnqueueError, "queue unavailable"
      end

      method.call(wait_until: wait_until)
    end

    expect { described_class.new(borrowing).schedule }.to raise_error(ActiveJob::EnqueueError, "queue unavailable")
    expect(borrowing.reminder_schedules.find_by!(kind: "three_days_before")).to have_attributes(enqueued_at: be_present)
    expect(borrowing.reminder_schedules.find_by!(kind: "due_date")).to have_attributes(enqueued_at: nil)

    described_class.new(borrowing).schedule

    expect(borrowing.reminder_schedules.pending).to be_empty
    expect(enqueued_jobs.filter_map { |job| job[:args].second if job[:job] == SendBorrowingReminderJob }).to contain_exactly("three_days_before", "due_date")
  end
end
