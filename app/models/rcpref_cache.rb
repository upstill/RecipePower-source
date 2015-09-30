# RcprefCache is a results cache based on Rcpref (i.e., collection) records
class RcprefCache < ResultsCache

  def user
    nil
  end

  # Memoize a query to get all the currently-defined entity types
  def typeset
    @typeset ||=
        (user ? user.collection_scope(:in_collection => true) : Rcpref).select(:entity_type).distinct.order("entity_type DESC").pluck :entity_type
  end

  # Apply the tag to the current set of result counts
  def count_tag tag, counts
    typeset.each do |type|
      subscope = itemscope.where('rcprefs.entity_type = ?', type)
      # Winnow the scope by restricting the set to Rcprefs referring to recipes in which EITHER
      # * The Rcpref's comment matches the tag's string, OR
      # * The recipe's title matches the tag's string, OR
      # * the recipe is tagged by the tag
      matchstr = "%#{tag.name}%"
      # r1 = Recipe.joins(:user_pointers).where("recipes.title ILIKE ? and rcprefs.user_id = 3", matchstr)
      # ids1 = subscope.joins("INNER JOIN recipes ON recipes.id = rcprefs.entity_id and recipes.title ILIKE '%salmon%' and rcprefs.user_id = 3")
      # ids1 = subscope.joins(%Q{INNER JOIN recipes ON recipes.id = rcprefs.entity_id and recipes.title ILIKE matchstr and rcprefs.user_id = 3})
      # ids1 = subscope.joins(%Q{INNER JOIN recipes ON recipes.id = rcprefs.entity_id and recipes.title ILIKE matchstr}).where("rcprefs.user_id = 3")
      sss1 = subscope.joins(%Q{INNER JOIN recipes ON recipes.id = rcprefs.entity_id}).where("recipes.title ILIKE ?", matchstr)
      sss1 = sss1.where("rcprefs.user_id = #{@id}") if @id
      sss1 = sss1.to_a.uniq { |rr| "#{rr.entity_type}#{rr.entity_id}"}

      sss2 = subscope.find_by_sql( %Q{SELECT * FROM rcprefs where rcprefs.comment ILIKE '#{matchstr}' } ).uniq { |rr| "#{rr.entity_type}#{rr.entity_id}"}

      sss3 = subscope.joins("INNER JOIN taggings ON taggings.entity_type = rcprefs.entity_type and taggings.entity_id = rcprefs.entity_id and taggings.tag_id = #{tag.id}")
      sss3 = sss3.to_a.uniq { |rr| "#{rr.entity_type}#{rr.entity_id}" }

      counts.incr sss1 # One extra point for matching in one field
      counts.incr sss2
      counts.incr sss3
      this_round = (sss1+sss2+sss3).uniq
      counts.incr this_round, 30 # Thirty points for matching this tag
    end
  end

end
