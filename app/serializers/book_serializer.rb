# Serializes a book for catalog and details responses.
class BookSerializer
  def initialize(book, borrowings: nil, status: nil)
    @book = book
    @borrowings = borrowings
    @status = status
  end

  def as_json(*)
    data = { serial_number: @book.serial_number, title: @book.title, author: @book.author, status: @status || @book.status }
    data[:archived_at] = @book.archived_at if @book.archived_at?
    data[:borrowings] = @borrowings.map { |borrowing| BorrowingSerializer.new(borrowing).as_json } if @borrowings
    data
  end
end
