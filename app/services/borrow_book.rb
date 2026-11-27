# Creates a borrowing while serializing state changes for one book.
class BorrowBook
  BORROWING_PERIOD = 30 * 24.hours

  def initialize(serial_number:, library_card_number:, borrowed_at: nil)
    @serial_number = serial_number
    @library_card_number = library_card_number
    @borrowed_at = borrowed_at
  end

  def call
    reader = Reader.find_by!(library_card_number: @library_card_number)
    borrowing = create_borrowing(reader)
    BorrowingReminderScheduler.new(borrowing).schedule_safely
    borrowing
  rescue ActiveRecord::RecordNotUnique
    raise BorrowingConflict, "The book is already borrowed."
  end

  private

  def create_borrowing(reader)
    Book.transaction do
      book = Book.lock.find_by!(serial_number: @serial_number)
      ensure_book_can_be_borrowed(book)
      create_borrowing_record(book, reader).tap do |borrowing|
        BorrowingReminderScheduler.new(borrowing).prepare
      end
    end
  end

  def ensure_book_can_be_borrowed(book)
    raise BorrowingConflict, "An archived book cannot be borrowed." if book.archived_at?
    raise BorrowingConflict, "The book is already borrowed." if book.active_borrowing
  end

  def create_borrowing_record(book, reader)
    borrowed_at = @borrowed_at || Time.current
    Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + BORROWING_PERIOD)
  end
end
