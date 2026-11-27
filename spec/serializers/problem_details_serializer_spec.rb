require "rails_helper"

RSpec.describe ProblemDetailsSerializer do
  it "serializes an RFC 9457 problem response" do
    serializer = described_class.new(
      type: "https://example.com/problems/invalid-book",
      status: :unprocessable_content,
      title: "Validation failed",
      detail: "The submitted data is invalid.",
      errors: { title: [ "can't be blank" ] }
    )

    expect(serializer.as_json).to eq(
      type: "https://example.com/problems/invalid-book",
      status: 422,
      title: "Validation failed",
      detail: "The submitted data is invalid.",
      errors: { title: [ "can't be blank" ] }
    )
    expect(serializer.render_options).to include(status: 422, content_type: "application/problem+json")
  end
end
