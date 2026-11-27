# A book loan with an exact 30-day due date and optional return time.
class Borrowing < ApplicationRecord
  belongs_to :book, inverse_of: :borrowings
  belongs_to :reader, inverse_of: :borrowings
  has_many :reminders, class_name: "BorrowingReminder", inverse_of: :borrowing

  validates :borrowed_at, :due_at, presence: true
  validates_with BorrowingTimestampsValidator
end
