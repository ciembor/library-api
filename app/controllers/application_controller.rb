# frozen_string_literal: true

# Base controller for the library API.
class ApplicationController < ActionController::API
  include ErrorHandling
  include RequestParameters
end
