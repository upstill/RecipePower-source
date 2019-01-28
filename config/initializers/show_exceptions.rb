require 'action_dispatch/middleware/show_exceptions'

module LogWithTemplate
  private
  def render_exception(env, exception)
    body = ErrorsController.action(rescue_responses[exception.class.name]).call(env)
    log_error(exception)
    body
  rescue => e
    super
  end
end

module ActionDispatch
  class ShowExceptions
    prepend LogWithTemplate
  end
end