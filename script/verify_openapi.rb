# Validates the generated contract details required by this API's OpenAPI 3.1 publication.
require "yaml"

document = YAML.safe_load_file(File.expand_path("../swagger/v1/swagger.yaml", __dir__))
required_paths = %w[/books /books/{serial_number} /books/{book_serial_number}/borrowings /books/{book_serial_number}/returns /readers /readers/{library_card_number}]

abort "OpenAPI version must be 3.1.x" unless document.fetch("openapi").start_with?("3.1.")
abort "OpenAPI document must define every API path" unless (required_paths - document.fetch("paths").keys).empty?
schemas = document.dig("components", "schemas")
abort "OpenAPI document must define reusable schemas" unless schemas.is_a?(Hash) && !schemas.empty?

problem_responses = document.fetch("paths").values.flat_map do |path_item|
  path_item.values.filter_map { |operation| operation["responses"] if operation.is_a?(Hash) }.flat_map(&:values).select { |response| response.dig("content", "application/problem+json", "schema", "$ref") == "#/components/schemas/problem" }
end
abort "OpenAPI document must define RFC 9457 error responses" if problem_responses.empty?
