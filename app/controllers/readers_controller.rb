# HTTP endpoints for registering and finding library readers.
class ReadersController < ApplicationController
  def create
    reader = Reader.new(reader_params)
    return render_validation_errors(reader) unless reader.save

    render json: { data: reader.api_data }, status: :created
  end

  def show
    render json: { data: Reader.find_by!(library_card_number: params[:library_card_number]).api_data }
  end

  private

  def reader_params
    params.require(:reader).permit(:library_card_number, :full_name, :email)
  end
end
