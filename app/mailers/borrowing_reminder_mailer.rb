# Builds the library's due-date reminder messages.
class BorrowingReminderMailer < ApplicationMailer
  SUBJECTS = { "three_days_before" => "Library book due in 3 days", "due_date" => "Library book due today" }.freeze

  def reminder(borrowing, kind)
    @borrowing = borrowing
    @kind = kind
    mail(to: borrowing.reader.email, subject: SUBJECTS.fetch(kind)) { |format| format.text { render plain: body } }
  end

  private

  def body
    reader = @borrowing.reader
    book = @borrowing.book
    "#{reader.full_name}, return #{book.title} (#{book.serial_number}) by #{@borrowing.due_at.iso8601}."
  end
end
