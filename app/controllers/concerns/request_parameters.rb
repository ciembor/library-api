# Extracts a required JSON object and permits its supported attributes.
module RequestParameters
  private

  def permitted_object(name, *attributes)
    object = params.require(name)
    raise ActionController::ParameterMissing, name unless object.is_a?(ActionController::Parameters)

    object.permit(*attributes)
  end
end
