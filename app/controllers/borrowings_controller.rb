# HTTP endpoint for borrowing a library book.
class BorrowingsController < ApplicationController
  def create
    borrowing = BorrowBook.new(
      serial_number: six_digit_identifier(:book_serial_number),
      library_card_number: six_digit_identifier(:library_card_number, borrowing_params[:library_card_number])
    ).call
    render json: { data: { borrowed_at: borrowing.borrowed_at, due_at: borrowing.due_at } }, status: :created
  end

  private

  def borrowing_params
    permitted_object(:borrowing, :library_card_number)
  end
end
