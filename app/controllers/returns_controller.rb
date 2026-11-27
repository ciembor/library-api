# HTTP endpoint for returning a library book.
class ReturnsController < ApplicationController
  def create
    borrowing = ReturnBook.new(serial_number: six_digit_identifier(:book_serial_number)).call
    render json: { data: ReturnSerializer.new(borrowing).as_json }
  end
end
