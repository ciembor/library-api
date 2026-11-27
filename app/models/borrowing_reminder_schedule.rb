# A durable outbox entry for a reminder job.
class BorrowingReminderSchedule < ApplicationRecord
  belongs_to :borrowing

  scope :pending, -> { where(enqueued_at: nil) }

  validates :kind, inclusion: { in: BorrowingReminder::KINDS }
  validates :scheduled_at, presence: true

  def enqueue(job_class)
    job = job_class.set(wait_until: scheduled_at).perform_later(borrowing_id, kind)
    raise ActiveJob::EnqueueError, "Reminder job could not be enqueued." unless job

    update!(enqueued_at: Time.current)
  end
end
