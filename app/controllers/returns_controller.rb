# HTTP endpoint for returning a library book.
class ReturnsController < ApplicationController
  def create
    borrowing = ReturnBook.new(serial_number: six_digit_identifier(:book_serial_number)).call
    render json: { data: { returned_at: borrowing.returned_at } }
  end
end
