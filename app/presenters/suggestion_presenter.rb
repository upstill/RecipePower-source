class SuggestionPresenter < BasePresenter
  presents :suggestion
  delegate :base, :viewer, :session, :filter, :results_cache, :results, to: :suggestion
end