
class SearchAllCache < RcprefCache

  def self.params_needed
    # The access parameter filters for private and public lists
    super + [:entity_type]
  end

  def sources
    nil
  end

  def stream_id
    "search-"+@entity_type.gsub(/\./,'-')
  end

  def itemscope
    Rcpref.all
  end

end
