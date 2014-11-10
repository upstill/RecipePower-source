module Templateer
  attr_accessor :object, :klass

  def initialize class_or_obj, options={}
    if class_or_obj.class == Class
      self.klass = class_or_obj
    else
      super
      class_or_obj.prep_params options[:uid] if options[:uid]
      self.klass = class_or_obj.class
    end
  end

  # Return EITHER the value of an object attribute OR a placeholder for use in a template
  # and defined by the data
  # If there's an object, we delegate attribute read calls.
  # Otherwise we return the placeholder
  def method_missing(meth, *args, &block)
    object ? object.send(meth, *args, &block) : placeholder(meth)
  end

  # Return a hash intended to be passed to the client for template substitution
  # We assume certain field values; others may be defined by subclasses
  def data
    unless @data
      @data = {}
      if @object
        @object.class.accessible_attributes.each { |key|
          key = key.to_sym
          @data[key] = @object.send(key) if @object.respond_to? key
        }
      end
    end
    @data
  end

  def object_type plural=false
    type = klass.to_s
    (plural ? type.pluralize : type).underscore
  end

  def human_name plural=false
    object_type(plural).sub('_', ' ')
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def element_id what
    "#{object_type}_#{what}"
  end

  def field_name what
    "#{object_type}[#{what}]"
  end

  def object_path
    "/#{object_type true}/#{self.id}"
  end

  def edit_path
    object_path+"/edit"
  end

  def tagdata
    object ? object.tagging_tags.map(&:attributes).to_json : ""
  end

  def edit_class
    "edit_#{object_type}"
  end

protected

  def placeholder attribute
    "%%#{attribute}%%".html_safe
  end

end
