require "rails_helper"

RSpec.describe PaginationParameters,
  mutant_expression: [ "PaginationParameters#valid?", "PaginationParameters#error_detail" ] do
  subject(:parameters) { described_class.new(query, default_per_page: 20, maximum_per_page: 100, maximum_page: 1_000_000) }

  describe "#valid?" do
    context "with valid query parameters" do
      let(:query) { {} }

      it "uses pagination defaults", mutant_expression: [ "PaginationParameters#valid?", "PaginationParameters#error_detail" ] do
        expect(parameters).to be_valid
        expect(parameters.to_h).to eq(page: 1, per_page: 20)
        expect(parameters.error_detail).to be_nil
      end
    end

    context "at the configured upper bounds" do
      let(:query) { { page: 1_000_000, per_page: 100 } }

      it "accepts both values", mutant_expression: [ "PaginationParameters#valid?", "PaginationParameters#error_detail" ] do
        expect(parameters).to be_valid
        expect(parameters.error_detail).to be_nil
      end
    end

    context "with configured defaults and bounds" do
      subject(:parameters) { described_class.new(query, default_per_page: 1, maximum_per_page: 1, maximum_page: 1) }

      let(:query) { { page: 1, per_page: 1 } }

      it "accepts its own boundaries" do
        expect(parameters).to be_valid
        expect(parameters.to_h).to eq(page: 1, per_page: 1)
      end
    end

    context "with an invalid page" do
      let(:query) { { page: 0 } }

      it "rejects the page", mutant_expression: [ "PaginationParameters#valid?", "PaginationParameters#error_detail" ] do
        expect(parameters).not_to be_valid
        expect(parameters.error_detail).to eq("page must be an integer between 1 and 1000000.")
      end
    end

    context "with an invalid page size" do
      let(:query) { { per_page: 101 } }

      it "rejects the page size", mutant_expression: [ "PaginationParameters#valid?", "PaginationParameters#error_detail" ] do
        expect(parameters).not_to be_valid
        expect(parameters.error_detail).to eq("per_page must be an integer between 1 and 100.")
      end
    end

    context "with a zero page size" do
      let(:query) { { per_page: 0 } }

      it "rejects the page size", mutant_expression: [ "PaginationParameters#valid?", "PaginationParameters#error_detail" ] do
        expect(parameters).not_to be_valid
        expect(parameters.error_detail).to eq("per_page must be an integer between 1 and 100.")
      end
    end

    context "with a non-numeric page size" do
      let(:query) { { per_page: "invalid" } }

      it "rejects the page size", mutant_expression: [ "PaginationParameters#valid?", "PaginationParameters#error_detail" ] do
        expect(parameters).not_to be_valid
        expect(parameters.error_detail).to eq("per_page must be an integer between 1 and 100.")
      end
    end

    context "with a non-scalar page value" do
      let(:query) { { page: [ 1 ] } }

      it "rejects the page", mutant_expression: [ "PaginationParameters#valid?", "PaginationParameters#error_detail" ] do
        expect(parameters).not_to be_valid
        expect(parameters.error_detail).to eq("page must be an integer between 1 and 1000000.")
      end
    end

    context "with unsupported integer representations" do
      [ " 1", "1 ", "+1", "01", "1e2", "1_0" ].each do |value|
        it "rejects #{value.inspect}" do
          parameters = described_class.new({ page: value }, default_per_page: 20, maximum_per_page: 100, maximum_page: 1_000_000)

          expect(parameters).not_to be_valid
        end
      end
    end

    context "with a page above the supported offset range" do
      let(:query) { { page: 1_000_001 } }

      it "rejects the page", mutant_expression: [ "PaginationParameters#valid?", "PaginationParameters#error_detail" ] do
        expect(parameters).not_to be_valid
        expect(parameters.error_detail).to eq("page must be an integer between 1 and 1000000.")
      end
    end
  end
end
