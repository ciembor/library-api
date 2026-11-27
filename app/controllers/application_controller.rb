# Base controller for the library API.
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordNotUnique, with: :render_record_not_unique
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

  private

  def render_problem(problem)
    status, title, detail, errors = problem.values_at(:status, :title, :detail, :errors)
    status = Rack::Utils.status_code(status)
    body = { type: "about:blank", title: title, status: status, detail: detail, errors: errors }.compact
    render json: body, status: status, content_type: "application/problem+json"
  end

  def render_validation_errors(record)
    render_problem(type: "about:blank", status: 422, title: "Validation failed", detail: "The submitted data is invalid.", errors: record.errors.to_hash)
  end

  def render_conflict(detail)
    render_problem(type: "about:blank", status: :conflict, title: "Conflict", detail: detail)
  end

  def render_not_found
    render_problem(type: "about:blank", status: :not_found, title: "Not found", detail: "The requested resource does not exist.")
  end

  def render_record_not_unique
    render_problem(type: "about:blank", status: 422, title: "Validation failed", detail: "A record with these unique values already exists.")
  end

  def render_parameter_missing(error)
    render_problem(type: "about:blank", status: :bad_request, title: "Bad request", detail: error.message)
  end

  def integer_parameter(name, default:, maximum:)
    value = params.fetch(name, default)
    integer = Integer(value, exception: false)
    return integer if integer&.positive? && integer <= maximum

    render_problem(type: "about:blank", status: :bad_request, title: "Bad request", detail: "#{name} must be an integer between 1 and #{maximum}.")
    nil
  end
end
