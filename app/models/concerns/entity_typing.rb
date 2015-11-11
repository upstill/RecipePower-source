# Support for ResultsCache classes which filter by entity_type and (possibly) subtype
# Includes translation between human-friendly strings and model names
module EntityTyping
  extend ActiveSupport::Concern

  included do
    def self.params_needed
      # The access parameter filters for private and public lists
      super + [:entity_type]
    end
  end

  def entity_type
    @entity_type ||= 'recipes'
  end

  # Return the entity type sans extensions
  def entity_type_root
    @etr ||= entity_type.sub(/\..*/, '')
  end

  def stream_id
    ((uid = defined?(super) && super) ? "#{uid}-" : '') + entity_type.gsub(/\./, '-')
  end

  def scope_constraints
    {
        entity_type: entity_type_to_model_name
    }
  end

  # Express a user-friendly name string as a class name for purposes of naming an entity_type
  def entity_type_to_model_name
    case root = entity_type_root.singularize
      when 'friend'
        'User'
      else
        root.camelize
    end
  end

  def entity_type_to_model
    entity_type_to_model_name.constantize
  end

  # Default itemscope by entity_type is to just search the model table
  def itemscope
    @itemscope ||= entity_type_to_model.unscoped
  end

end