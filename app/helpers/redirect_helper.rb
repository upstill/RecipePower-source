module RedirectHelper

  def push_state action=nil
    { pushState: response_service.push_state(action) }.compact
  end
end
