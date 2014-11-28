require "string_utils.rb"
module Templateer
  attr_accessor :object, :klass

  def initialize class_or_obj=nil, options={}
    if class_or_obj && (class_or_obj.class != Class)
      super
      class_or_obj.prep_params options[:uid] if options[:uid]
      self.klass = class_or_obj.class
    else # For a class constant or nil, just record it
      self.klass = class_or_obj
    end
  end

  # Return EITHER the value of an object attribute OR a placeholder for use in a template
  # and defined by the data
  # If there's an object, we delegate attribute read calls.
  # Otherwise we return the placeholder
  def method_missing(meth, *args, &block)
    if object
      begin
        object.send(meth, *args, &block)
      rescue
        if meth.to_sym == :url
          "/#{object.class.to_s.underscore.pluralize}/#{object.id}"
        else
          "No method #{meth} found for decorated #{object.class.to_s}"
        end
      end
    else
      placeholder(meth)
    end
  end

  # Return a hash intended to be passed to the client for template substitution
  # We assume certain field values; others may be defined by subclasses
  def data needed=nil
    unless @data
      @data = {
          obj_type_singular: object_type,
          obj_type_plural: object_type(true),
          human_name: human_name(false, false),
          human_name_capitalize: human_name(false, true),
          human_name_plural: human_name(true, false),
          human_name_plural_capitalize: human_name(true, true),
          tagging_tag_data: tagdata
      }
      if @object
        toget = needed || (@object.class.accessible_attributes + [:id])
        toget.each { |key|
          key = key.to_sym
          @data[key] = @object.send(key) if @object.respond_to? key
        }
      end
    end
    @data
  end

  def object_type plural=false
    if klass
      type = klass.to_s
      (plural ? type.pluralize : type).underscore
    else
      placeholder plural ? "obj_type_plural" : "obj_type_singular"
    end
  end

  def human_name plural=false, capitalize=true
    if klass
      name = object_type(plural).sub('_', ' ')
      capitalize ? name.split.map(&:capitalize)*' ' : name
    else
      placeholder %Q{human_name#{"_plural" if plural}#{"_capitalize" if capitalize}}
    end
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
