class RcprefServices

  # Find matches for the given string among entities of the given type, in the context of an optional scope
  # Result is a new scope on Taggings
  def self.match matchstr, type, scope=nil
    scope = (scope || Tagging.unscoped).where('taggings.entity_type = ?', type)
    # Different search for each taggable type
    case type
      when "Recipe"
        subscope.joins(%Q{INNER JOIN recipes ON recipes.id = taggings.entity_id}).where("recipes.title ILIKE ?", matchstr)
      when "User"
      when "List"
        subscope.joins(%Q{INNER JOIN lists ON lists.id = taggings.entity_id}).where("lists.title ILIKE ?", matchstr)
      when "Site"
      when "Feed"
      when "FeedEntry"
    end
  end

end