# frozen_string_literal: true

# Parses and validates pagination query parameters.
class PaginationParameters
  attr_reader :page, :per_page

  def initialize(params, default_per_page:, maximum_per_page:)
    @maximum_per_page = maximum_per_page
    @page = parse(params.fetch(:page, 1))
    @per_page = parse(params.fetch(:per_page, default_per_page))
  end

  def valid?
    page&.positive? && per_page&.positive? && per_page <= @maximum_per_page
  end

  def error_detail
    return "page must be an integer greater than 0." unless page&.positive?
    return "per_page must be an integer between 1 and #{@maximum_per_page}." unless per_page&.positive? && per_page <= @maximum_per_page

    nil
  end

  def to_h
    { page: page, per_page: per_page }
  end

  private

  def parse(value)
    Integer(value, exception: false)
  end
end
