
class SearchAllCache < ResultsCache
  include EntityTyping

  def stream_id
    'search'
  end

end
