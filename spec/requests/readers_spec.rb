require "rails_helper"

RSpec.describe "Readers API", type: :request do
  let(:reader_attributes) { { library_card_number: 123_456, full_name: "Ada Lovelace", email: "ada@example.com" } }

  def json
    response.parsed_body
  end

  def expect_problem(status, title)
    expect(response).to have_http_status(status)
    expect(response.media_type).to eq("application/problem+json")
    expect(json).to include("type" => "about:blank", "title" => title, "status" => Rack::Utils.status_code(status), "detail" => satisfy(&:present?))
  end

  describe "POST /readers" do
    it "registers a reader" do
      post "/readers", params: { reader: reader_attributes }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.media_type).to eq("application/json")
      expect(json).to eq("data" => reader_attributes.stringify_keys)
    end

    it "returns validation errors" do
      post "/readers", params: { reader: reader_attributes.merge(email: "invalid") }, as: :json

      expect_problem(422, "Validation failed")
      expect(json.dig("errors", "email")).to include("is invalid")
    end

    it "returns a bad request when the reader object is missing" do
      post "/readers", params: {}, as: :json

      expect_problem(:bad_request, "Bad request")
    end

    it "returns a client error for malformed reader structures" do
      [ nil, [], "reader", 123_456 ].each do |reader|
        post "/readers", params: { reader: reader }, as: :json

        expect_problem(:bad_request, "Bad request")
      end

      expect(Reader.count).to eq(0)
    end

    it "rejects duplicate card numbers and email addresses without creating another reader" do
      Reader.create!(reader_attributes)

      post "/readers", params: { reader: reader_attributes.merge(email: "other@example.com") }, as: :json
      expect_problem(:unprocessable_content, "Validation failed")

      post "/readers", params: { reader: reader_attributes.merge(library_card_number: 654_321, email: "ADA@example.com") }, as: :json
      expect_problem(:unprocessable_content, "Validation failed")
      expect(Reader.count).to eq(1)
    end
  end

  describe "GET /readers/:library_card_number" do
    it "returns the reader" do
      reader = Reader.create!(reader_attributes)

      get "/readers/#{reader.library_card_number}"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(json).to eq("data" => reader_attributes.stringify_keys)
    end

    it "returns not found for an unknown reader" do
      get "/readers/999999"
      expect_problem(:not_found, "Not found")
    end

    it "rejects malformed reader identifiers" do
      [ "99999", "1000000", "123456abc" ].each do |identifier|
        get "/readers/#{identifier}"

        expect_problem(:bad_request, "Bad request")
      end
    end
  end
end
