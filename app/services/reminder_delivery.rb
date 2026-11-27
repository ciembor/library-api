# Persists and logs the payload that represents delivery in this MVP.
class ReminderDelivery
  def initialize(borrowing:, kind:)
    @borrowing = borrowing
    @kind = kind
  end

  def deliver
    reminder = BorrowingReminder.create!(borrowing: @borrowing, kind: @kind, payload: payload, sent_at: Time.current)
    Rails.logger.info(reminder.payload.to_json)
    reminder
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  private

  def payload
    message = BorrowingReminderMailer.reminder(@borrowing, @kind).message
    book = @borrowing.book
    { to: message.to.first, subject: message.subject, body: message.body.decoded, reader: ReaderSerializer.new(@borrowing.reader).as_json,
      book: { serial_number: book.serial_number, title: book.title }, due_at: @borrowing.due_at.iso8601, kind: @kind }
  end
end
