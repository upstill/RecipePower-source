class SuggestionPresenter < BasePresenter
  presents :suggestion
  delegate :base, :viewer, :session, :filter, :results_cache, :results, to: :suggestion

  def sections
    results.collect { |key, value|
      yield( key, value)
    }.join('').html_safe
  end

  def present
    sections { |name, content|
       content_tag(:h3, name)+
       content_tag(:p, content)
    }.html_safe
  end

end

class UserSuggestionPresenter < SuggestionPresenter
  presents :user_suggestion


end

class TagSuggestionPresenter < SuggestionPresenter
  presents :tag_suggestion

end

class RecipeSuggestionPresenter < SuggestionPresenter
  presents :recipe_suggestion

end

class CollectionSuggestionPresenter < SuggestionPresenter
  presents :collection_suggestion

end

class GlobalCollectionSuggestionPresenter < CollectionSuggestionPresenter
  presents :global_collection_suggestion

end

class RecentCollectionSuggestionPresenter < CollectionSuggestionPresenter
  presents :recent_collection_suggestion

end
