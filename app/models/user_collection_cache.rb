# Recently-viewed recipes of the given user
class UserCollectionCache < RcprefCache

  def self.params_needed
    # The access parameter filters for private and public lists
    super + [:entity_type]
  end

  def user
    @user ||= User.find_by(id: @id) if @id
  end

  # The sources are a user, a list of users, or nil (for the master global list)
  def sources
    user.id
  end

  # Return the entity type sans extensions
  def entity_type_root
    @etr ||= (@entity_type.sub(/\..*/, '') if @entity_type.present?)
  end

  def itemscope
    if user
      constraints = { :sort_by => :viewed, :in_collection => true }
      if entity_type_root
        constraints[:entity_type] = entity_type_root.singularize.camelize
      end
      user.collection_scope constraints
    end
  end

  def stream_id
    [ :user, @id, @entity_type.gsub(/\./,'-') ].join('-')
  end

end
