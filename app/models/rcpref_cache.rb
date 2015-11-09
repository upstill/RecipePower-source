# RcprefCache is a results cache based on Rcpref (i.e., collection) records
class RcprefCache < ResultsCache

  def user
    nil
  end

  # Memoize a query to get all the currently-defined entity types
  def typeset
    @typeset ||= @entity_type ?
        [ entity_type_to_model_name(@entity_type) ] :
        (user ? user.collection_scope(:in_collection => true) : Rcpref).
            select(:entity_type).
            distinct.
            order("entity_type DESC").
            pluck(:entity_type)
  end

  # Apply the tag to the current set of result counts
  def count_tag tag, counts
    matchstr = "%#{tag.name}%"
    typeset.each do |type|
      modelclass = type.constantize
      scope = modelclass.joins :user_pointers
      if @id
        scope = scope.where('rcprefs.user_id = ? and rcprefs.in_collection = true', @id.to_s)
        scope = scope.where('rcprefs.private = false') unless @id == @userid # Only non-private entities if the user is not the viewer
      end

      # First, match on the comments using the rcpref
      bump_counts scope.where('rcprefs.comment ILIKE ?', matchstr), type

      # Now match on the entitie's relevant string field(s), for which we defer to the class
      if modelclass.respond_to? :strscopes
        [modelclass.strscopes(scope, tag.name)].flatten.each { |strscope|
          bump_counts strscope, type
        }
      end

      scope = scope.joins(:user_pointers).where('taggings.tag_id = ?', tag.id.to_s)
      if @id
        scope = scope.where 'taggings.user_id = ?', @userid.to_s
      end
      bump_counts scope, type
    end
  end

  protected

  def bump_counts scope, type
    counts.incr scope.
                    pluck(&:id).
                    uniq.
                    collect { |id| type.to_s+id.to_s }

  end

end
