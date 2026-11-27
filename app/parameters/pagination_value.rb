# Converts one scalar pagination value to an integer.
class PaginationValue
  def initialize(value)
    @value = value
  end

  def integer
    return @value if @value.is_a?(Integer)
    return unless @value.is_a?(String) && @value.match?(/\A(?:0|[1-9]\d*)\z/)

    Integer(@value, exception: false)
  end
end
