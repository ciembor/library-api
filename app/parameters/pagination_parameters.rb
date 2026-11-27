# frozen_string_literal: true

# Parses and validates pagination query parameters.
class PaginationParameters
  attr_reader :page, :per_page

  def initialize(params, default_per_page:, maximum_per_page:, maximum_page:)
    @maximum_page = maximum_page
    @maximum_per_page = maximum_per_page
    @page = integer_value(params.fetch(:page, 1))
    @per_page = integer_value(params.fetch(:per_page, default_per_page))
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

  private

  # Keeps the query-value parsing policy with its pagination contract.
  # :reek:FeatureEnvy,UtilityFunction { enabled: false }
  def integer_value(value)
    return value if value.is_a?(Integer)
    return unless value.is_a?(String) && value.match?(/\A(?:0|[1-9]\d*)\z/)

    Integer(value, exception: false)
  end
end
