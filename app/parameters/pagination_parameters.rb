# frozen_string_literal: true

# Parses and validates pagination query parameters.
class PaginationParameters
  attr_reader :page, :per_page

  def initialize(params, default_per_page:, maximum_per_page:, maximum_page:)
    @maximum_page = maximum_page
    @maximum_per_page = maximum_per_page
    @page = PaginationValue.new(params.fetch(:page, 1)).integer
    @per_page = PaginationValue.new(params.fetch(:per_page, default_per_page)).integer
  end

  def valid?
    page&.positive? && page <= @maximum_page && per_page&.positive? && per_page <= @maximum_per_page
  end

  def error_detail
    return "page must be an integer between 1 and #{@maximum_page}." unless page&.positive? && page <= @maximum_page
    "per_page must be an integer between 1 and #{@maximum_per_page}." unless per_page&.positive? && per_page <= @maximum_per_page
  end

  def to_h
    { page: page, per_page: per_page }
  end
end
