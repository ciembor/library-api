# HTTP endpoint for borrowing a library book.
class BorrowingsController < ApplicationController
  def create
    borrowing = BorrowBook.new(serial_number: params[:book_serial_number], library_card_number: borrowing_params[:library_card_number]).call
    render json: { data: BorrowingTimestampsSerializer.new(borrowing).as_json }, status: :created
  end

  private

  def borrowing_params
    permitted_object(:borrowing, :library_card_number)
  end
end
