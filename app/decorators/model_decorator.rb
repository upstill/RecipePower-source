# This class of Decorator handles ALL persisted object classes.
# It defines convenience methods for deriving names for the objects,
# but the main point is to provide #as_base_class for the use of polymorphic_path, which
# otherwise would try to build different paths for STI subclasses individually
class ModelDecorator < Draper::Decorator
  # ##### Extract various forms of the model's name
  # Recipe => 'Recipe'
  # FeedEntry => 'FeedEntry'

  # Define the attributes of the model in a way amenable to translating between types
  # This is a hash whose keys are the accessible attributes of the model,
  # and the values are those attributes as translated into a "common" representation,
  # e.g., 'name' (commonly known as 'title'), 'logo'/'picurl' ('image'), 'home' ('url').
  # For example, the :url of a recipe corresponds to the :home of a site
  # In most cases, the attributes pass from one model to the other without changing name,
  # but, importantly, no translation occurs if the target model is missing such an attribute
  def self.attrmap
    # We memoize the map for each type
    @@AttrMaps ||= {}
    # By default, all accessible attributes map to themselves
    @@AttrMaps[self.object_class.to_s] ||= self.object_class.mass_assignable_attributes.inject(ActiveSupport::HashWithIndifferentAccess.new) { |memo, attrname|
      memo[attrname] = attrname
      memo
    }
    @@AttrMaps[self.object_class.to_s]
  end

  def self.attrmap_inverted
    @@AttrMapsInverted ||= {}
    @@AttrMapsInverted[self.object_class.to_s] ||= ActiveSupport::HashWithIndifferentAccess.new self.attrmap.invert
    @@AttrMapsInverted[self.object_class.to_s]
  end

  # Translate params for one class to those for another.
  # NB: generally speaking, only common parameters (e.g., title, url, description) work properly
  def translate_params_for params, entity
    params ||= {}
    ed = entity.is_a?(Draper::Decorator) ? entity : entity.decorate
    return params if ed.class == self.class
    inmap = self.class.attrmap
    outmap = ed.class.attrmap_inverted # ActiveSupport::HashWithIndifferentAccess.new ed.class.attrmap.invert
    result = ActiveSupport::HashWithIndifferentAccess.new
    params.each {|key, value|
      (common_name = inmap[key]) &&
          (output_key = outmap[common_name]) &&
          (result[output_key] = value)
    }
    result
  end

  # Translation from label names to attribute names
  def attribute_for what
    self.class.attrmap_inverted[what.to_s]
  end

  def class_name
    model_name.name
  end

  def base_class_name
    object.class.base_class.to_s
  end

  # Reduce the object to its base class for the use of polymorphic_path
  def as_base_class
    bc = object.class.base_class
    (bc == object.class) ? object : object.becomes(bc)
  end

  # Recipe => 'recipe'
  # FeedEntry => 'feed_entry'
  def singular_name
    model_name.singular
  end

  # Recipe => 'recipes'
  # FeedEntry => 'feed_entries'
  def plural_name
    model_name.plural
  end

  # Recipe => 'recipe'
  # FeedEntry => 'feed_entry'
  def element_name
    model_name.element
  end

  # Recipe => 'Recipe'
  # FeedEntry => 'Feed entry'
  def human_name plural=false, capitalize=true
    name = model_name.human
    name = name.pluralize if plural
    capitalize ? name : name.downcase
  end

  # Recipe => 'recipe'
  # FeedEntry => 'feed_entry'
  def param_key
    model_name.param_key
  end

  # Recipe => 'recipes'
  # FeedEntry => 'feed_entries'
  def collection_name
    model_name.collection
  end

  # Present an STI subclass as the base class
  def base_object
    object.class == object.class.base_class ? object : object.becomes(object.class.base_class)
  end

  # Provide the path or object suitable for passing to link_to, going to the object's primary page.
  # In most cases, this will be the object's #show page
  def homelink
    object
  end

  def dom_id
    "#{object.model_name.singular}_#{object.id}"
  end
end
