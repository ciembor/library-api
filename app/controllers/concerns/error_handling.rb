# frozen_string_literal: true

# Maps application and framework failures to RFC 9457 responses.
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordNotUnique, with: :render_record_not_unique
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
    rescue_from BorrowingConflict, with: :render_borrowing_conflict
  end

  private

  def render_problem(**attributes)
    render(**ProblemDetailsSerializer.new(**attributes).render_options)
  end

  def render_validation_errors(record)
    render_problem(status: :unprocessable_content, title: "Validation failed", detail: "The submitted data is invalid.", errors: record.errors.to_hash)
  end

  def render_conflict(detail)
    render_problem(status: :conflict, title: "Conflict", detail: detail)
  end

  def render_borrowing_conflict(error)
    render_conflict(error.message)
  end

  def render_not_found
    render_problem(status: :not_found, title: "Not found", detail: "The requested resource does not exist.")
  end

  def render_record_not_unique
    render_problem(status: :unprocessable_content, title: "Validation failed", detail: "A record with these unique values already exists.")
  end

  def render_parameter_missing(error)
    render_bad_request(error.message)
  end

  def render_bad_request(detail)
    render_problem(status: :bad_request, title: "Bad request", detail: detail)
  end
end
