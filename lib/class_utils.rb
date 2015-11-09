
# Look up a constant for a particular kind of, e.g., Presenter, related to a class or its ancestors
def const_for object, qualifier=nil
  # First try investigating defined constants directly
  object.class.ancestors.detect { |anc|
    next if anc.to_s.match /^#</
    return nil if anc == ActiveRecord::Base # Stop checking at ActiveRecord base class
    next if anc.to_s.match /::/
    classname = "#{anc}#{qualifier}"
    if Object.const_defined? classname
      return classname.constantize
    end
  }
end

# Express a user-friendly name string as a class name for purposes of naming an entity_type
def entity_type_to_model_name str
  case result = str.to_s.singularize.camelize
    when 'Friend'
      'User'
    else
      result
  end
end

def model_name_to_entity_type klass
  case result = klass.to_s.underscore
    when 'user'
      'friend'
    else
      result
  end
end
