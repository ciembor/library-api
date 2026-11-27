# Closes the active borrowing while serializing state changes for one book.
class ReturnBook
  def initialize(serial_number:, returned_at: Time.current)
    @serial_number = serial_number
    @returned_at = returned_at
  end

  def call
    Book.transaction { close_borrowing }
  end

  private

  def close_borrowing
    book = Book.lock.find_by!(serial_number: @serial_number)
    borrowing = book.active_borrowing || raise(BorrowingConflict, "The book is already available.")
    borrowing.update!(returned_at: @returned_at)
    borrowing
  end
end
