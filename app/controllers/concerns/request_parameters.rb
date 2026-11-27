# Extracts a required JSON object and permits its supported attributes.
module RequestParameters
  private

  def permitted_object(name, *attributes)
    object = params.require(name)
    raise ActionController::ParameterMissing, name unless object.is_a?(ActionController::Parameters)

    object.permit(*attributes)
  end

  def six_digit_identifier(name)
    value = Integer(params.fetch(name), exception: false)
    return value if value&.between?(100_000, 999_999)

    raise ActionController::ParameterMissing, name
  end
end
