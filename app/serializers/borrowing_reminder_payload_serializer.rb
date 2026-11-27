# Serializes the persisted representation of a borrowing reminder.
class BorrowingReminderPayloadSerializer
  def initialize(borrowing, kind)
    @borrowing = borrowing
    @kind = kind
  end

  def as_json(*)
    message = BorrowingReminderMailer.reminder(@borrowing, @kind).message
    book = @borrowing.book
    { to: message.to.first, subject: message.subject, body: message.body.decoded, reader: ReaderSerializer.new(@borrowing.reader).as_json,
      book: { serial_number: book.serial_number, title: book.title }, due_at: @borrowing.due_at.iso8601, kind: @kind }
  end
end
