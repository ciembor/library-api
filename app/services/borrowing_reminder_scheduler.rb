# Schedules both due-date reminder kinds after a borrowing is committed.
class BorrowingReminderScheduler
  def initialize(borrowing)
    @borrowing = borrowing
  end

  def schedule
    @borrowing.reminder_schedules.pending.find_each { |schedule| schedule.enqueue(SendBorrowingReminderJob) }
  end

  def schedule_safely
    schedule
  rescue ActiveJob::EnqueueError => error
    Rails.logger.error("Reminder scheduling failed for borrowing #{@borrowing.id}: #{error.message}")
  end

  def prepare
    schedules.each { |kind, scheduled_at| @borrowing.reminder_schedules.find_or_create_by!(kind: kind, scheduled_at: scheduled_at) }
  end

  private

  def schedules
    due_at = @borrowing.due_at
    [ [ "three_days_before", due_at - 3.days ], [ "due_date", due_at ] ]
  end
end
