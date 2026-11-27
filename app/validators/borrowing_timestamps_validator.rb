# frozen_string_literal: true

# Validates the temporal invariants of a borrowing record.
class BorrowingTimestampsValidator < ActiveModel::Validator
  BORROWING_PERIOD = 30 * 24.hours

  def validate(record)
    BorrowingTimestampConstraints.new(record, borrowing_period: options.fetch(:borrowing_period, BORROWING_PERIOD)).validate
  end
end
