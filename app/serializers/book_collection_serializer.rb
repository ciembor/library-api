# Serializes a paginated collection of catalog books.
class BookCollectionSerializer
  def initialize(books, page:, per_page:)
    @books = books
    @page = page
    @per_page = per_page
  end

  def as_json(*)
    page_books = @books.offset((@page - 1) * @per_page).limit(@per_page)
    { data: page_books.map { |book| BookSerializer.new(book).as_json }, meta: { page: @page, per_page: @per_page, total: @books.count } }
  end
end
