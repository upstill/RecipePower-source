module RedirectHelper

  def push_state action=nil
    # TODO: modify originator according to action
    { pushState: [ response_service.originator, response_service.page_title ] }
  end
end
