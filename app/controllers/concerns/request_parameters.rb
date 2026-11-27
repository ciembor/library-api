# Extracts a required JSON object and permits its supported attributes.
module RequestParameters
  private

  def permitted_object(name, *attributes)
    object = params.require(name)
    raise ActionController::ParameterMissing, name unless object.is_a?(ActionController::Parameters)

    object.permit(*attributes)
  end

  def six_digit_identifier(name, value = params.fetch(name))
    identifier = value.to_s
    return identifier.to_i if /\A[1-9]\d{5}\z/.match?(identifier)

    raise ActionController::ParameterMissing, name
  end
end
