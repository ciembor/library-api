require "swagger_helper"

RSpec.describe "Library API", openapi_spec: "v1/swagger.yaml", type: :request do
  PROBLEM_SCHEMA = { "$ref" => "#/components/schemas/problem" }.freeze
  ENVELOPE = ->(schema) { { type: :object, required: [ "data" ], properties: { data: schema } } }

  path "/books" do
    post "Create a book" do
      tags "Books"
      consumes "application/json"
      produces "application/json"
      parameter name: :book, in: :body, schema: { type: :object, required: [ "book" ], properties: { book: { "$ref" => "#/components/schemas/book_input" } } }

      response "201", "book created" do
        let(:book) { { serial_number: 123_456, title: "Dune", author: "Frank Herbert" } }
        schema ENVELOPE.call("$ref" => "#/components/schemas/book")

        run_test!
      end

      response "400", "book payload missing", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:book) { nil }

        run_test!
      end

      response "422", "book is invalid", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:book) { { serial_number: 123_456, title: "", author: "Frank Herbert" } }

        run_test!
      end
    end

    get "List available catalog entries" do
      tags "Books"
      produces "application/json"
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response "200", "catalog returned" do
        before { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
        schema type: :object, required: %w[data meta], properties: {
          data: { type: :array, items: { "$ref" => "#/components/schemas/book" } },
          meta: { type: :object, required: %w[page per_page total] }
        }

        run_test!
      end

      response "400", "pagination is invalid", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:page) { 0 }

        run_test!
      end
    end
  end

  path "/books/{serial_number}" do
    parameter name: :serial_number, in: :path, type: :integer

    get "Get a book and its borrowing history" do
      tags "Books"
      produces "application/json"

      response "200", "book returned" do
        let(:serial_number) { 123_456 }
        before do
          reader = Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com")
          book = Book.create!(serial_number: serial_number, title: "Dune", author: "Frank Herbert")
          borrowed_at = Time.current
          Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
        end
        schema ENVELOPE.call(type: :object, allOf: [ { "$ref" => "#/components/schemas/book" } ], properties: { borrowings: { type: :array, items: { "$ref" => "#/components/schemas/borrowing" } } })

        run_test!
      end

      response "404", "book missing", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:serial_number) { 999_999 }

        run_test!
      end
    end

    delete "Archive an available book" do
      tags "Books"

      response "204", "book archived" do
        let(:serial_number) { 123_456 }
        before { Book.create!(serial_number: serial_number, title: "Dune", author: "Frank Herbert") }

        run_test!
      end

      response "404", "book missing", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:serial_number) { 999_999 }

        run_test!
      end

      response "409", "book is borrowed", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:serial_number) { 123_456 }
        before do
          reader = Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com")
          book = Book.create!(serial_number: serial_number, title: "Dune", author: "Frank Herbert")
          borrowed_at = Time.current
          Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
        end

        run_test!
      end
    end
  end

  path "/readers" do
    post "Register a reader" do
      tags "Readers"
      consumes "application/json"
      produces "application/json"
      parameter name: :reader, in: :body, schema: { type: :object, required: [ "reader" ], properties: { reader: { "$ref" => "#/components/schemas/reader" } } }

      response "201", "reader created" do
        let(:reader) { { library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com" } }
        schema ENVELOPE.call("$ref" => "#/components/schemas/reader")

        run_test!
      end

      response "400", "reader payload missing", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:reader) { nil }

        run_test!
      end

      response "422", "reader is invalid", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:reader) { { library_card_number: 654_321, full_name: "Ada Lovelace", email: "invalid" } }

        run_test!
      end
    end
  end

  path "/readers/{library_card_number}" do
    parameter name: :library_card_number, in: :path, type: :integer

    get "Get a reader" do
      tags "Readers"
      produces "application/json"

      response "200", "reader returned" do
        let(:library_card_number) { 654_321 }
        before { Reader.create!(library_card_number: library_card_number, full_name: "Ada Lovelace", email: "ada@example.com") }
        schema ENVELOPE.call("$ref" => "#/components/schemas/reader")

        run_test!
      end

      response "404", "reader missing", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:library_card_number) { 999_999 }

        run_test!
      end
    end
  end

  path "/books/{book_serial_number}/borrowings" do
    parameter name: :book_serial_number, in: :path, type: :integer

    post "Borrow a book" do
      tags "Borrowings"
      consumes "application/json"
      produces "application/json"
      parameter name: :borrowing, in: :body, schema: { type: :object, required: [ "borrowing" ], properties: { borrowing: { type: :object, required: [ "library_card_number" ], properties: { library_card_number: { type: :integer } } } } }

      response "201", "borrowing created" do
        let(:book_serial_number) { 123_456 }
        let(:borrowing) { { borrowing: { library_card_number: 654_321 } } }
        before do
          Book.create!(serial_number: book_serial_number, title: "Dune", author: "Frank Herbert")
          Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com")
        end
        schema ENVELOPE.call(type: :object, required: %w[borrowed_at due_at], properties: { borrowed_at: { type: :string, format: "date-time" }, due_at: { type: :string, format: "date-time" } })

        run_test!
      end

      response "400", "borrowing payload missing", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:book_serial_number) { 123_456 }
        let(:borrowing) { nil }

        run_test!
      end

      response "404", "book or reader missing", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:book_serial_number) { 999_999 }
        let(:borrowing) { { borrowing: { library_card_number: 654_321 } } }

        run_test!
      end

      response "409", "book already borrowed", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:book_serial_number) { 123_456 }
        let(:borrowing) { { borrowing: { library_card_number: 654_321 } } }
        before do
          reader = Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com")
          book = Book.create!(serial_number: book_serial_number, title: "Dune", author: "Frank Herbert")
          borrowed_at = Time.current
          Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
        end

        run_test!
      end
    end
  end

  path "/books/{book_serial_number}/returns" do
    parameter name: :book_serial_number, in: :path, type: :integer

    post "Return a book" do
      tags "Borrowings"
      produces "application/json"

      response "200", "return recorded" do
        let(:book_serial_number) { 123_456 }
        before do
          reader = Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com")
          book = Book.create!(serial_number: book_serial_number, title: "Dune", author: "Frank Herbert")
          borrowed_at = Time.current
          Borrowing.create!(book: book, reader: reader, borrowed_at: borrowed_at, due_at: borrowed_at + 30.days)
        end
        schema ENVELOPE.call(type: :object, required: [ "returned_at" ], properties: { returned_at: { type: :string, format: "date-time" } })

        run_test!
      end

      response "404", "book missing", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:book_serial_number) { 999_999 }

        run_test!
      end

      response "409", "book is not borrowed", content: { "application/problem+json" => { schema: PROBLEM_SCHEMA } } do
        let(:book_serial_number) { 123_456 }
        before { Book.create!(serial_number: book_serial_number, title: "Dune", author: "Frank Herbert") }

        run_test!
      end
    end
  end
end
