module RatingsHelper
  
  def link_to_remove_fields(name, f)
    f.hidden_field(:_destroy) + link_to(name, "#", class: "remove_fields") # link_to_function(name, "remove_fields(this)")
  end

  def summarize_ratings(ratings)
    enumerate_strs ratings.collect { |r| "<strong>#{r.value_as_text}</strong>" }
  end
end
