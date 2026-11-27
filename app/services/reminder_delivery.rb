# Persists and logs the payload that represents delivery in this MVP.
class ReminderDelivery
  def initialize(borrowing:, kind:)
    @borrowing = borrowing
    @kind = kind
  end

  def deliver
    create_reminder.tap { |reminder| Rails.logger.info(reminder.payload.to_json) if reminder }
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  private

  def create_reminder
    Book.transaction { create_reminder_for_active_borrowing }
  end

  def create_reminder_for_active_borrowing
    borrowing = locked_borrowing
    return if borrowing.returned_at?

    payload = BorrowingReminderPayloadSerializer.new(borrowing, @kind).as_json
    BorrowingReminder.create!(borrowing: borrowing, kind: @kind, payload: payload, sent_at: Time.current)
  end

  def locked_borrowing
    Book.lock.find(@borrowing.book_id).borrowings.includes(:reader).find(@borrowing.id)
  end
end
