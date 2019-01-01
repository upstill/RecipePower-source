# Providing helpers with access to Authoreyes functionality
module AuthorizationHelper

  def permitted_to? privilege, object_or_symbol = nil, options = {}
    response_service.controller_instance.permitted_to? privilege, object_or_symbol, options
  end
end