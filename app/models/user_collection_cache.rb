# Recently-viewed recipes of the given user
class UserCollectionCache < ResultsCache
  include EntityTyping

  def user
    @user ||= User.find @id
  end

  def itemscope
    @itemscope ||= user.collection_scope( { :sort_by => :viewed, :in_collection => true }.merge scope_constraints)
  end

  # Return
  def strscopes matcher, modelclass
    if modelclass.respond_to? :strscopes
      modelclass.strscopes(matcher).collect { |innerscope|
        innerscope = innerscope.joins(:user_pointers).where('"rcprefs"."user_id" = ? and "rcprefs"."in_collection" = true', @id.to_s)
        innerscope = innerscope.where('"rcprefs"."private" = false') unless @id == @viewerid # Only non-private entities if the user is not the viewer
        innerscope
      }
    else
      []
    end
  end

  # Apply a tag to the current set of result counts
  def count_tag tag, counts
    matchstr = "%#{tag.name}%"
    typeset.each do |type|
      modelclass = type.constantize
      scope = modelclass.joins :user_pointers
      scope = scope.where('"rcprefs"."user_id" = ? and "rcprefs"."in_collection" = true', @id.to_s)
      scope = scope.where('"rcprefs"."private" = false') unless @id == @viewerid # Only non-private entities if the user is not the viewer

      # First, match on the comments using the rcpref
      counts.incr_by_scope scope.where('"rcprefs"."comment" ILIKE ?', matchstr)

      # Now match on the entity's relevant string field(s), for which we defer to the class
      strscopes("%#{tag.name}%", modelclass).each { |innerscope| counts.incr_by_scope innerscope }
      strscopes(tag.name, modelclass).each { |innerscope| counts.incr_by_scope innerscope, 30 }

      subscope = modelclass.joins(:taggings).where 'taggings.tag_id = ?', tag.id.to_s
=begin
      # TODO: We're not filtering by user taggings (the more the merrier)
      if @id
        subscope = subscope.where 'taggings.user_id = ?', @id.to_s
      end
=end
      counts.incr_by_scope subscope, 1
    end
  end

  # Memoize a query to get all the currently-defined entity types
  def typeset
    @typeset ||=
    case modelname = itemscope.model.to_s
      when 'Rcpref'
        itemscope.
            select(:entity_type).
            distinct.
            pluck(:entity_type).
            sort
      else
        [ modelname ]
    end
  end

end
