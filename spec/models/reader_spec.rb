require "rails_helper"

RSpec.describe Reader do
  let(:reader) { described_class.create!(library_card_number: 123_456, full_name: "Ada Lovelace", email: "Ada@Example.com") }

  it "requires a six-digit card number, full name, and email" do
    expect(reader).to be_valid
    expect(described_class.new(library_card_number: 99_999, full_name: "Ada", email: "ada@example.com")).not_to be_valid
    expect(described_class.new(library_card_number: 1_000_000, full_name: "Ada", email: "ada@example.com")).not_to be_valid
    expect(described_class.new(library_card_number: 222_222, full_name: " ", email: "ada@example.com")).not_to be_valid
    expect(described_class.new(library_card_number: 222_222, full_name: "Ada", email: " ")).not_to be_valid
    expect(described_class.new(library_card_number: 222_222, full_name: "Ada", email: "invalid")).not_to be_valid
  end

  it "rejects duplicate card numbers and email addresses regardless of case" do
    reader
    expect(described_class.new(library_card_number: 123_456, full_name: "Grace", email: "grace@example.com")).not_to be_valid
    expect(described_class.new(library_card_number: 222_222, full_name: "Grace", email: "ada@example.com")).not_to be_valid
  end
end
