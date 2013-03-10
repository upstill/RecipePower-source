module RatingsHelper
  def summarize_ratings(ratings)
    enumerate_strs ratings.collect { |r| "<strong>#{r.value_as_text}</strong>" }
  end
end
