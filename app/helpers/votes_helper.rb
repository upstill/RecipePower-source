module VotesHelper

  # Link to submit a vote on the given entity. 'up' is true for an upvote
  def vote_link entity, up, style
    return unless (path = polymorphic_path([:vote, entity]) rescue nil)
    return unless respond_to?(path)
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
    "vote-button btn btn-default btn-xs glyphicon glyphicon-thumbs-"+(up ? "up" : "down")
  end

  def vote_div_class style
    "vote-div-"+style
  end

  def vote_div_id entity
    "vote-"+entity.class.to_s.downcase+entity.id.to_s
  end

  def vote_button_replacer entity, style="h"
    [
        "div#"+vote_div_id(entity),
        vote_button(entity, style: style)
    ]
  end

  def vote_button entity, options={} # Style can be 'h', with more to come
    style = options[:style] || "h"
    return "" unless (uplink = vote_link(entity, true, style)) && (downlink = vote_link(entity, false, style))
    up_button = link_to "",
                        uplink,
                        method: "post",
                        remote: true,
                        title: "Vote this up",
                        class: vote_button_class(true, style)
    down_button = link_to "",
                          downlink,
                          method: "post",
                          remote: true,
                          title: "Vote this down",
                          class: vote_button_class(false, style)
    vote_counter = (entity.upvotes > 0 && entity.upvotes.to_s) || ""
    count = content_tag :span, vote_counter, class: vote_count_class(style)
    content_tag :div, (up_button+count+down_button).html_safe, class: vote_div_class(style), id: vote_div_id(entity)
  end

end
