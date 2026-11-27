require "rails_helper"

RSpec.describe PaginationParameters do
  subject(:parameters) { described_class.new(query, default_per_page: 20, maximum_per_page: 100) }

  context "with valid query parameters" do
    let(:query) { {} }

    it "uses pagination defaults" do
      expect(parameters).to be_valid
      expect(parameters.to_h).to eq(page: 1, per_page: 20)
      expect(parameters.error_detail).to be_nil
    end
  end

  context "with an invalid page" do
    let(:query) { { page: 0 } }

    it "explains the page constraint" do
      expect(parameters).not_to be_valid
      expect(parameters.error_detail).to eq("page must be an integer greater than 0.")
    end
  end

  context "with an invalid page size" do
    let(:query) { { per_page: 101 } }

    it "explains the page size constraint" do
      expect(parameters).not_to be_valid
      expect(parameters.error_detail).to eq("per_page must be an integer between 1 and 100.")
    end
  end

  context "with a non-numeric page size" do
    let(:query) { { per_page: "invalid" } }

    it "rejects the page size" do
      expect(parameters).not_to be_valid
      expect(parameters.error_detail).to eq("per_page must be an integer between 1 and 100.")
    end
  end
end
