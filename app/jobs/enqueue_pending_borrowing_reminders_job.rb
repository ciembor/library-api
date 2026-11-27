# Recovers reminder jobs whose enqueue did not complete during borrowing creation.
class EnqueuePendingBorrowingRemindersJob < ApplicationJob
  # Active Job invokes this callback without instance-specific arguments.
  # :reek:UtilityFunction { enabled: false }
  def perform
    BorrowingReminderSchedule.pending.includes(:borrowing).find_each do |schedule|
      BorrowingReminderScheduler.new(schedule.borrowing).schedule
    end
  end
end
