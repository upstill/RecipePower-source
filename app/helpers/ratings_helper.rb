module RatingsHelper
    def summarize_ratings(ratings)
	englishize_list(ratings.collect { |r| "<strong>#{r.value_as_text}</strong>" }.join ', ')
    end
end
