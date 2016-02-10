module RedirectHelper

  def push_state action=nil
    # TODO: modify originator according to action
    { pushState: response_service.push_state(action) }
  end
end
