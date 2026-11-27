# Prepares a reminder only while the borrowing remains active.
class SendBorrowingReminderJob < ApplicationJob
  def perform(borrowing_id, kind)
    @kind = kind
    borrowing = Borrowing.includes(:book, :reader).find_by(id: borrowing_id)
    return unless borrowing && borrowing.returned_at.nil?

    ReminderDelivery.new(borrowing: borrowing, kind: @kind).deliver
  end
end
