require "rails_helper"

RSpec.describe "Books API", type: :request do
  let(:book_attributes) { { serial_number: 123_456, title: "Dune", author: "Frank Herbert" } }

  def json
    response.parsed_body
  end

  def create_book(attributes = book_attributes)
    Book.create!(attributes)
  end

  let(:reader) { Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com") }

  def expect_problem(status, title)
    expect(response).to have_http_status(status)
    expect(response.media_type).to eq("application/problem+json")
    expect(json).to include("type" => "about:blank", "title" => title, "status" => Rack::Utils.status_code(status), "detail" => satisfy(&:present?))
  end

  describe "POST /books" do
    it "creates a book" do
      post "/books", params: { book: book_attributes }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.media_type).to eq("application/json")
      expect(json).to eq("data" => book_attributes.merge("status" => "available").stringify_keys)
    end

    it "returns validation errors" do
      post "/books", params: { book: book_attributes.merge(title: "") }, as: :json

      expect_problem(422, "Validation failed")
      expect(json.dig("errors", "title")).to include("can't be blank")
    end

    it "returns a bad request when the book object is missing" do
      post "/books", params: {}, as: :json

      expect_problem(:bad_request, "Bad request")
    end

    it "converts a database uniqueness error into a validation problem" do
      allow_any_instance_of(Book).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      post "/books", params: { book: book_attributes }, as: :json

      expect_problem(422, "Validation failed")
    end
  end

  describe "GET /books" do
    it "returns non-archived books with status and pagination metadata" do
      available = create_book
      borrowed = create_book(book_attributes.merge(serial_number: 123_457))
      archived = create_book(book_attributes.merge(serial_number: 123_458, title: "Archived", archived_at: Time.current))
      Borrowing.create!(book: borrowed, reader: reader, borrowed_at: Time.utc(2026, 11, 27), due_at: Time.utc(2026, 12, 27))

      get "/books"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(json).to eq(
        "data" => [
          { "serial_number" => available.serial_number, "title" => available.title, "author" => available.author, "status" => "available" },
          { "serial_number" => borrowed.serial_number, "title" => borrowed.title, "author" => borrowed.author, "status" => "borrowed" }
        ],
        "meta" => { "page" => 1, "per_page" => 20, "total" => 2 }
      )
      expect(archived).to be_persisted
    end

    it "paginates with page and per_page" do
      create_book
      second = create_book(book_attributes.merge(serial_number: 123_457))

      get "/books", params: { page: 2, per_page: 1 }

      expect(json).to include("data" => [ include("serial_number" => second.serial_number) ], "meta" => { "page" => 2, "per_page" => 1, "total" => 2 })
    end

    it "rejects invalid page parameters" do
      get "/books", params: { page: 0 }
      expect_problem(:bad_request, "Bad request")

      get "/books", params: { per_page: 101 }
      expect_problem(:bad_request, "Bad request")

      get "/books", params: { page: "invalid" }
      expect_problem(:bad_request, "Bad request")
    end

    it "accepts pagination boundaries" do
      get "/books", params: { page: 1, per_page: 1 }
      expect(response).to have_http_status(:ok)

      get "/books", params: { page: 1_000_000, per_page: 100 }
      expect(response).to have_http_status(:ok)
    end

    it "rejects malformed, non-scalar, and excessive pagination values" do
      [ { page: [] }, { page: { value: 1 } }, { page: "" }, { page: nil }, { page: -1 }, { page: "1.5" }, { page: "01" }, { page: "+1" }, { page: 1_000_001 },
        { per_page: [] }, { per_page: { value: 1 } }, { per_page: "" }, { per_page: nil }, { per_page: -1 }, { per_page: "1.5" }, { per_page: "01" }, { per_page: "+1" }, { per_page: 101 },
        { page: 0, per_page: 0 } ].each do |params|
        get "/books", params: params

        expect_problem(:bad_request, "Bad request")
      end
    end
  end

  describe "GET /books/:serial_number" do
    it "returns book data and borrowing history ordered from newest" do
      book = create_book
      older = Borrowing.create!(book: book, reader: reader, borrowed_at: Time.utc(2026, 10, 1), due_at: Time.utc(2026, 10, 31))
      older.update!(returned_at: Time.utc(2026, 10, 3))
      newer = Borrowing.create!(book: book, reader: reader, borrowed_at: Time.utc(2026, 11, 27), due_at: Time.utc(2026, 12, 27))

      get "/books/#{book.serial_number}"

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "status")).to eq("borrowed")
      expect(json.dig("data", "borrowings")).to match([
        include("borrowed_at" => newer.borrowed_at.as_json, "due_at" => newer.due_at.as_json, "returned_at" => nil, "reader" => include("email" => reader.email)),
        include("borrowed_at" => older.borrowed_at.as_json, "returned_at" => older.returned_at.as_json)
      ])
    end

    it "returns not found for an unknown book" do
      get "/books/999999"
      expect_problem(:not_found, "Not found")
    end

    it "rejects malformed book identifiers" do
      get "/books/123456abc"

      expect_problem(:bad_request, "Bad request")
    end
  end

  describe "invalid request payloads" do
    it "returns a client error without creating a book for malformed book structures" do
      [ nil, [], "book", 123_456 ].each do |book|
        post "/books", params: { book: book }, as: :json

        expect_problem(:bad_request, "Bad request")
      end

      expect(Book.count).to eq(0)
    end

    it "does not allow clients to set protected book attributes" do
      post "/books", params: { book: book_attributes.merge(archived_at: Time.current, status: "borrowed") }, as: :json

      expect(response).to have_http_status(:created)
      expect(Book.last).to have_attributes(archived_at: nil, status: "available")
    end
  end

  describe "DELETE /books/:serial_number" do
    it "archives an available book and is idempotent" do
      book = create_book

      delete "/books/#{book.serial_number}"
      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(book.reload.archived_at).to be_present

      delete "/books/#{book.serial_number}"
      expect(response).to have_http_status(:no_content)
    end

    it "rejects archiving a borrowed book" do
      book = create_book
      Borrowing.create!(book: book, reader: reader, borrowed_at: Time.utc(2026, 11, 27), due_at: Time.utc(2026, 12, 27))

      delete "/books/#{book.serial_number}"

      expect_problem(:conflict, "Conflict")
      expect(book.reload.archived_at).to be_nil
    end
  end

  describe "POST /books/:serial_number/borrowings" do
    it "borrows an available book" do
      book = create_book
      borrowed_at = Time.current

      post "/books/#{book.serial_number}/borrowings", params: { borrowing: { library_card_number: reader.library_card_number } }, as: :json

      borrowing = Borrowing.find_by!(book: book)
      expect(response).to have_http_status(:created)
      expect(response.media_type).to eq("application/json")
      expect(json).to eq("data" => { "borrowed_at" => borrowing.borrowed_at.as_json, "due_at" => borrowing.due_at.as_json })
      expect(borrowing).to have_attributes(reader: reader, due_at: be_within(1.second).of(borrowed_at + 30.days))
    end

    it "returns a bad request when borrowing data is missing" do
      post "/books/#{book_attributes[:serial_number]}/borrowings", params: {}, as: :json

      expect_problem(:bad_request, "Bad request")
    end

    it "rejects malformed borrowing structures and missing card numbers" do
      book = create_book

      [ nil, [], "borrowing", 123_456, {} ].each do |borrowing|
        post "/books/#{book.serial_number}/borrowings", params: { borrowing: borrowing }, as: :json

        expect_problem(:bad_request, "Bad request")
      end

      expect(Borrowing.where(book: book)).to be_empty
    end

    it "rejects malformed book identifiers without creating a borrowing" do
      post "/books/123456abc/borrowings", params: { borrowing: { library_card_number: reader.library_card_number } }, as: :json

      expect_problem(:bad_request, "Bad request")
      expect(Borrowing.count).to eq(0)
    end

    it "returns not found for an unknown book or reader" do
      post "/books/999999/borrowings", params: { borrowing: { library_card_number: reader.library_card_number } }, as: :json
      expect_problem(:not_found, "Not found")

      create_book
      post "/books/#{book_attributes[:serial_number]}/borrowings", params: { borrowing: { library_card_number: 999_999 } }, as: :json
      expect_problem(:not_found, "Not found")
    end

    it "rejects archived and borrowed books" do
      archived = create_book(book_attributes.merge(archived_at: Time.current))
      post "/books/#{archived.serial_number}/borrowings", params: { borrowing: { library_card_number: reader.library_card_number } }, as: :json
      expect_problem(:conflict, "Conflict")

      available = create_book(book_attributes.merge(serial_number: 123_457))
      borrowed_at = Time.current
      Borrowing.create!(book: available, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
      post "/books/#{available.serial_number}/borrowings", params: { borrowing: { library_card_number: reader.library_card_number } }, as: :json
      expect_problem(:conflict, "Conflict")
    end
  end

  describe "POST /books/:serial_number/returns" do
    it "returns a borrowed book and preserves its history" do
      book = create_book
      borrowed_at = Time.current
      borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)

      post "/books/#{book.serial_number}/returns", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(json).to eq("data" => { "returned_at" => borrowing.reload.returned_at.as_json })
      expect(Borrowing.where(book: book).count).to eq(1)
      expect(book.reload.status).to eq("available")
    end

    it "returns conflicts for an available book and not found for an unknown book" do
      book = create_book
      post "/books/#{book.serial_number}/returns", as: :json
      expect_problem(:conflict, "Conflict")

      post "/books/999999/returns", as: :json
      expect_problem(:not_found, "Not found")
    end

    it "rejects malformed book identifiers" do
      post "/books/123456abc/returns", as: :json

      expect_problem(:bad_request, "Bad request")
    end
  end
end
