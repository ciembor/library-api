# frozen_string_literal: true

# Validates the temporal invariants of a borrowing record.
class BorrowingTimestampsValidator < ActiveModel::Validator
  BORROWING_PERIOD = 30 * 24.hours

  def validate(record)
    validate_due_at(record)
    validate_returned_at(record)
  end

  private

  # Validates the supplied record against the validator configuration.
  # :reek:FeatureEnvy { enabled: false }
  def validate_due_at(record)
    borrowed_at = record.borrowed_at
    due_at = record.due_at
    return if borrowed_at.blank? || due_at.blank?
    return if due_at == borrowed_at + borrowing_period

    record.errors.add(:due_at, "must be 30 days after borrowing")
  end

  # Applies a record-local relation, while the borrowing period is irrelevant here.
  # :reek:UtilityFunction { enabled: false }
  def validate_returned_at(record)
    borrowed_at = record.borrowed_at
    returned_at = record.returned_at
    return if returned_at.blank? || borrowed_at.blank?
    return unless returned_at < borrowed_at

    record.errors.add(:returned_at, "must be on or after borrowing")
  end

  def borrowing_period
    options.fetch(:borrowing_period, BORROWING_PERIOD)
  end
end
