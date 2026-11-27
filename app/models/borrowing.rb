# A book loan with an exact 30-day due date and optional return time.
class Borrowing < ApplicationRecord
  belongs_to :book, inverse_of: :borrowings
  belongs_to :reader, inverse_of: :borrowings

  validates :borrowed_at, :due_at, presence: true
  validate :due_at_matches_borrowed_at
  validate :returned_at_follows_borrowed_at

  private

  def due_at_matches_borrowed_at
    return if borrowed_at.blank? || due_at.blank?

    errors.add(:due_at, "must be 30 days after borrowing") unless due_at == borrowed_at + 30.days
  end

  def returned_at_follows_borrowed_at
    return if returned_at.blank? || borrowed_at.blank?

    errors.add(:returned_at, "must be after borrowing") if returned_at < borrowed_at
  end
end
