# HTTP endpoints for cataloguing and inspecting library books.
class BooksController < ApplicationController
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  def create
    book = Book.new(book_params)
    return render_validation_errors(book) unless book.save

    render json: { data: book.api_data }, status: :created
  end

  def index
    page = integer_parameter(:page, default: 1, maximum: Float::INFINITY)
    per_page = integer_parameter(:per_page, default: DEFAULT_PER_PAGE, maximum: MAX_PER_PAGE)
    return if performed?

    books = Book.where(archived_at: nil).includes(:active_borrowing).order(:serial_number)
    render json: { data: books.offset((page - 1) * per_page).limit(per_page).map(&:api_data), meta: { page: page, per_page: per_page, total: books.count } }
  end

  def show
    book = find_book
    borrowings = book.borrowings.includes(:reader).order(borrowed_at: :desc)
    render json: { data: book.api_data(borrowings: borrowings) }
  end

  def destroy
    book = find_book
    return render_conflict("A borrowed book cannot be archived.") if book.active_borrowing

    book.update!(archived_at: Time.current) unless book.archived_at?
    head :no_content
  end

  private

  def book_params
    params.require(:book).permit(:serial_number, :title, :author)
  end

  def find_book
    Book.find_by!(serial_number: params[:serial_number])
  end
end
