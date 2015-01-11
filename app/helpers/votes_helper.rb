module VotesHelper

  # Link to submit a vote on the given entity. 'up' is true for an upvote
  def vote_link entity, up, style
    return unless (path = polymorphic_path([:vote, entity]) rescue nil)
    # return unless respond_to?(path)
    query = { up: up }
    query[:style] = style if (style != "h") # h is the default style
    assert_query path, query
    # { :controller => "votes", :action => "create" }
  end

  def vote_params entity, up
    { entity_type: entity.class.to_s.downcase, entity_id: entity.id, up: up }
  end

  def vote_count_class style
    "vote-count-"+style
  end

  def vote_button_class up, style
    "vote-button glyphicon glyphicon-thumbs-"+(up ? "up" : "down")
  end

  def vote_div_class style
    "vote-div-"+style
  end

end
