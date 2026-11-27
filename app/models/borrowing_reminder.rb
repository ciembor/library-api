# A persisted record of a reminder prepared for a borrowing.
class BorrowingReminder < ApplicationRecord
  KINDS = %w[three_days_before due_date].freeze

  belongs_to :borrowing, inverse_of: :reminders

  validates :kind, inclusion: { in: KINDS }
  validates :payload, :sent_at, presence: true
end
