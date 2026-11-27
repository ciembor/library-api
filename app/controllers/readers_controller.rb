# HTTP endpoints for registering and finding library readers.
class ReadersController < ApplicationController
  def create
    reader = Reader.new(reader_params)
    return render_validation_errors(reader) unless reader.save

    render json: { data: ReaderSerializer.new(reader).as_json }, status: :created
  end

  def show
    reader = Reader.find_by!(library_card_number: params[:library_card_number])
    render json: { data: ReaderSerializer.new(reader).as_json }
  end

  private

  def reader_params
    permitted_object(:reader, :library_card_number, :full_name, :email)
  end
end
