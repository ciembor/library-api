# Schedules both due-date reminder kinds after a borrowing is committed.
class BorrowingReminderScheduler
  def initialize(borrowing)
    @borrowing = borrowing
  end

  def schedule
    due_at = @borrowing.due_at
    enqueue("three_days_before", due_at - 3.days)
    enqueue("due_date", due_at)
  end

  private

  def enqueue(kind, scheduled_at)
    SendBorrowingReminderJob.set(wait_until: scheduled_at).perform_later(@borrowing.id, kind)
  end
end
