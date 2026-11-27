# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.1.0',
      info: {
        title: 'Library API',
        version: 'v1',
        description: 'API used by library staff to manage books, readers and borrowings.'
      },
      paths: {},
      servers: [ { url: '/' } ],
      components: {
        schemas: {
          book: {
            type: :object,
            required: %w[serial_number title author status],
            properties: {
              serial_number: { type: :integer, minimum: 100_000, maximum: 999_999 },
              title: { type: :string }, author: { type: :string },
              status: { type: :string, enum: %w[available borrowed] }
            }
          },
          book_input: {
            type: :object,
            required: %w[serial_number title author],
            properties: {
              serial_number: { type: :integer, minimum: 100_000, maximum: 999_999 },
              title: { type: :string }, author: { type: :string }
            }
          },
          reader: {
            type: :object,
            required: %w[library_card_number full_name email],
            properties: {
              library_card_number: { type: :integer, minimum: 100_000, maximum: 999_999 },
              full_name: { type: :string }, email: { type: :string, format: :email }
            }
          },
          borrowing: {
            type: :object,
            required: %w[borrowed_at due_at returned_at reader],
            properties: {
              borrowed_at: { type: :string, format: 'date-time' },
              due_at: { type: :string, format: 'date-time' },
              returned_at: { type: %w[string null], format: 'date-time' },
              reader: { '$ref' => '#/components/schemas/reader' }
            }
          },
          problem: {
            type: :object,
            required: %w[type title status detail],
            properties: {
              type: { type: :string, format: :uri }, title: { type: :string },
              status: { type: :integer }, detail: { type: :string },
              errors: { type: :object, additionalProperties: { type: :array, items: { type: :string } } }
            }
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
