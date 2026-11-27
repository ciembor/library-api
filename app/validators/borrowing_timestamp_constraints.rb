# frozen_string_literal: true

# Applies borrowing timestamp constraints to one record validation.
class BorrowingTimestampConstraints
  def initialize(record, borrowing_period:)
    @record = record
    @borrowing_period = borrowing_period
  end

  def validate
    validate_due_at
    validate_returned_at
  end

  private

  def validate_due_at
    borrowed_at = @record.borrowed_at
    due_at = @record.due_at
    return if borrowed_at.blank? || due_at.blank?
    return if due_at == borrowed_at + @borrowing_period

    @record.errors.add(:due_at, "must be 30 days after borrowing")
  end

  def validate_returned_at
    borrowed_at = @record.borrowed_at
    returned_at = @record.returned_at
    return if returned_at.blank? || borrowed_at.blank?
    return unless returned_at < borrowed_at

    @record.errors.add(:returned_at, "must be after borrowing")
  end
end
