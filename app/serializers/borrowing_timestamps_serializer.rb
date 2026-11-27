# Serializes the timestamps returned after a borrowing state transition.
class BorrowingTimestampsSerializer
  def initialize(borrowing)
    @borrowing = borrowing
  end

  def as_json(*)
    { borrowed_at: @borrowing.borrowed_at, due_at: @borrowing.due_at }
  end
end
