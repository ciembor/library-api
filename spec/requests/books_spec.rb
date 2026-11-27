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
end
