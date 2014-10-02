class Suggestion < ActiveRecord::Base

  attr_accessible :base, :viewer, :session, :filter, :results_cache, :results, :time_next

  belongs_to :base, :polymorphic => true
  belongs_to :viewer, :class_name => "User"
  belongs_to :results_cache
  serialize :results, JSON  # A structured collection of, say, headings and content.
  # Typically, one or more entries will be placeholders for later streaming with a results_cache
  def self.find_or_make(user, viewer, queryparams, session_id)
    self.find_or_create_by( base: user, viewer: viewer, filter: queryparams, session: session_id)
  end
end

class UserSuggestion < Suggestion

end

class TagSuggestion < Suggestion

end

class RecipeSuggestion < Suggestion

end

class CollectionSuggestion < Suggestion

end

class GlobalCollectionSuggestion < CollectionSuggestion

end

class RecentCollectionSuggestion < CollectionSuggestion

end
