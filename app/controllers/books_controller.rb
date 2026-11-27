# HTTP endpoints for cataloguing and inspecting library books.
class BooksController < ApplicationController
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100
  MAX_PAGE = 1_000_000

  def create
    book = Book.new(book_params)
    return render_validation_errors(book) unless book.save

    render json: { data: BookSerializer.new(book).as_json }, status: :created
  end

  def index
    pagination = PaginationParameters.new(params, default_per_page: DEFAULT_PER_PAGE, maximum_per_page: MAX_PER_PAGE, maximum_page: MAX_PAGE)
    return render_bad_request(pagination.error_detail) unless pagination.valid?

    books = Book.where(archived_at: nil).includes(:active_borrowing).order(:serial_number)
    render json: BookCollectionSerializer.new(books, **pagination.to_h).as_json
  end

  def show
    book = find_book
    render json: { data: serialized_details(book) }
  end

  def destroy
    ArchiveBook.new(serial_number: six_digit_identifier(:serial_number)).call
    head :no_content
  end

  private

  def book_params
    permitted_object(:book, :serial_number, :title, :author)
  end

  def find_book
    Book.find_by!(serial_number: six_digit_identifier(:serial_number))
  end

  def serialized_details(book)
    borrowings = book.borrowings.includes(:reader).order(borrowed_at: :desc, id: :desc).to_a
    BookSerializer.new(book, borrowings: borrowings, status: history_status(borrowings)).as_json
  end

  # Derives a response field from the immutable history snapshot.
  # :reek:UtilityFunction { enabled: false }
  def history_status(borrowings)
    borrowings.any? { |borrowing| !borrowing.returned_at } ? "borrowed" : "available"
  end
end
