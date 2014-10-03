class Suggestion < ActiveRecord::Base

  attr_accessible :base, :viewer, :session, :filter, :results_cache, :results, :pending, :ready

  belongs_to :base, :polymorphic => true
  belongs_to :viewer, :class_name => "User"
  belongs_to :results_cache
  serialize :results, JSON  # A structured collection of, say, headings and content.
  # Typically, one or more entries will be placeholders for later streaming with a results_cache
  def self.find_or_make(user, viewer, queryparams, session_id)
    self.find_or_create_by( base: user, viewer: viewer, filter: queryparams, session: session_id) do |sug|
      # Before saving the suggestions, try to make the results ready
      sug.make_ready
    end
  end

  def sugtime
    @sugtime ||= 1
  end

  # Process the sugtime parameter for limiting # of accesses
  def time_check thistime=nil
    @sugtime = thistime ? (thistime.to_i*2) : 1
  end

  def timeout?
    sugtime > 30
  end

  # Take a shot at making the results. If it can't be done directly, throw it into background
  def make_ready
    return true if ready? # Do nothing if it's ready

    unless pending # Ready by default
      self.results = { :Lists => "Some lists", "Friends" => "Some Friends" }
      ready
    end

  end

  def ready
    @ready = true
  end

  def ready?
    @ready
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
