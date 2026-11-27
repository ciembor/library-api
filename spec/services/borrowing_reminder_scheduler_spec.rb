require "rails_helper"

RSpec.describe BorrowingReminderScheduler do
  let(:due_at) { Time.utc(2026, 12, 27, 12) }
  let(:borrowing) { instance_double(Borrowing, id: 42, due_at: due_at) }
  let(:three_days_job) { instance_double(ActiveJob::ConfiguredJob) }
  let(:due_date_job) { instance_double(ActiveJob::ConfiguredJob) }

  it "schedules each reminder at its exact due-date offset" do
    expect(SendBorrowingReminderJob).to receive(:set).with(wait_until: due_at - 3.days).and_return(three_days_job)
    expect(three_days_job).to receive(:perform_later).with(42, "three_days_before")
    expect(SendBorrowingReminderJob).to receive(:set).with(wait_until: due_at).and_return(due_date_job)
    expect(due_date_job).to receive(:perform_later).with(42, "due_date")

    described_class.new(borrowing).schedule
  end
end
