# Serializes a borrowing and its reader for book history responses.
class BorrowingSerializer
  def initialize(borrowing)
    @borrowing = borrowing
  end

  def as_json(*)
    {
      borrowed_at: @borrowing.borrowed_at,
      due_at: @borrowing.due_at,
      returned_at: @borrowing.returned_at,
      reader: ReaderSerializer.new(@borrowing.reader).as_json
    }
  end
end
