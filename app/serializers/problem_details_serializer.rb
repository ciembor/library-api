# frozen_string_literal: true

# Serializes an RFC 9457 problem details response.
class ProblemDetailsSerializer
  def initialize(**attributes)
    @attributes = attributes
  end

  def render_options
    { json: as_json, status: status, content_type: "application/problem+json" }
  end

  def as_json(*)
    { type: type, title: title, status: status, detail: detail, errors: errors }.compact
  end

  private

  def type
    @attributes.fetch(:type, "about:blank")
  end

  def title
    @attributes.fetch(:title)
  end

  def status
    Rack::Utils.status_code(@attributes.fetch(:status))
  end

  def detail
    @attributes.fetch(:detail)
  end

  def errors
    @attributes[:errors]
  end
end
