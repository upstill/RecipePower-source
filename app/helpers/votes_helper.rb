module VotesHelper

  # Link to submit a vote on the given entity. 'up' is true for an upvote
  def vote_link entity, up, style
    query = { up: up }
    query[:style] = style if (style != "h") # h is the default style
    assert_query polymorphic_path([:vote, entity]), query
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

  def vote_button entity, options={} # Style can be 'h', with more to come
    style = options[:style] || "h"
    # up_button = button_to_submit "", vote_link(entity, true, style), class: vote_button_class(true, style)
    # down_button = button_to_submit "", vote_link(entity, false, style), class: vote_button_class(false, style)
    up_button = link_to "",
                        vote_link(entity, true, style),
                        method: "post",
                        remote: true,
                        # form: { "data-type" => "json" },
                        class: vote_button_class(true, style)
    down_button = link_to "",
                          vote_link(entity, false, style),
                          method: "post",
                          remote: true,
                          # form: { "data-type" => "json" },
                          class: vote_button_class(false, style)
    count = content_tag :span, entity.upvotes.to_s, class: vote_count_class(style)
    content_tag :div, (up_button+count+down_button).html_safe, class: vote_div_class(style), id: vote_div_id(entity)
  end

  def vote_button_replacement entity, style
    [
      "div#"+vote_div_id(entity),
      vote_button(entity, style)
    ]
  end

  end
