# This class of Decorator handles ALL persisted object classes.
# It defines convenience methods for deriving names for the objects,
# but the main point is to provide #as_base_class for the use of polymorphic_path, which
# otherwise would try to build different paths for STI subclasses individually
class ModelDecorator < Draper::Decorator
  # ##### Extract various forms of the model's name
  # Recipe => 'Recipe'
  # FeedEntry => 'FeedEntry'

  def class_name
    model_name.name
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


end