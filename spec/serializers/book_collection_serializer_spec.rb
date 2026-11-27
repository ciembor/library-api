require "rails_helper"

RSpec.describe BookCollectionSerializer do
  let(:first_book) { Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert") }
  let(:second_book) { Book.create!(serial_number: 123_457, title: "Foundation", author: "Isaac Asimov") }

  it "serializes one page and pagination metadata" do
    first_book
    second_book

    expect(described_class.new(Book.order(:serial_number), page: 2, per_page: 1).as_json).to eq(
      data: [ BookSerializer.new(second_book).as_json ], meta: { page: 2, per_page: 1, total: 2 }
    )
  end
end
