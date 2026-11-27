# Archives an available book while serializing changes to its state.
class ArchiveBook
  def initialize(serial_number:, archived_at: nil)
    @serial_number = serial_number
    @archived_at = archived_at
  end

  def call
    Book.transaction { archive }
  end

  private

  def archive
    book = Book.lock.find_by!(serial_number: @serial_number)
    raise BorrowingConflict, "A borrowed book cannot be archived." if book.active_borrowing

    book.update!(archived_at: @archived_at || Time.current) unless book.archived_at?
    book
  end
end
