# Serializes the timestamp returned after closing a borrowing.
class ReturnSerializer
  def initialize(borrowing)
    @borrowing = borrowing
  end

  def as_json(*)
    { returned_at: @borrowing.returned_at }
  end
end
