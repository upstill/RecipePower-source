class DisplayServices
  attr_reader :klass, :object, :viewer, :class_name
  attr_accessor :result_type

  def initialize viewer, object_or_class_or_class_name=nil
    @viewer = viewer
    case object_or_class_or_class_name
      when Class
        self.klass = object_or_class_or_class_name
      when nil
      when String
        self.class_name = object_or_class_or_class_name
      else
        self.object = object_or_class_or_class_name
    end
  end

=begin
  # Display style is different for Users acc'ng to they're the viewer, friends of the viewer, or others
  def display_style object=nil
    object ||= @object
    k = object ? object.class : klass
    if k == User
      if object == @viewer
        'viewer'
      elsif @viewer && (@viewer.follows? object)
        'friend'
      else
        'user'
      end
    else
      k.to_s.underscore.downcase
    end
  end

  def card_class
    "#{display_style}-card"
  end

  def panel_class
    class_name == 'User' ? 'friends' : display_style.pluralize
  end

  def panel_button_class
    "#{display_style}-button"
  end

  # The label for the group of panels associated with a card
  def panels_label
    case display_style
      when 'viewer'
        'my collection'
      when 'friend', 'user'
        'collection'
      when 'recipe'
        'related'
      when 'feed'
        'entries'
      when 'list'
        'contents'
      else
        display_style.pluralize
    end
  end

  # The class of the label used in the header for a group of panels
  def panels_label_class
    "#{display_style}-label"
  end

  def page_class
    "#{display_style}-page"
  end

  # The label for a panel of results
  def panel_label
    case class_name
      when 'Feed'
        'feeds'
      when 'User'
        'friends'
      when 'Recipe'
        'recipes'
      when 'List'
        'treasuries'
      when nil
        'collection'
      else
        'Huh?!?'
    end
  end

  def style_class
    class_name.downcase.pluralize
  end

  # The label for a link to the given object
  def link_label
    class_name.pluralize.upcase
  end
=end

  def result_type
    @result_type ||= ResultType.new class_name
  end

  def result_type= rt
    @result_type = ResultType.new rt
    @klass = @result_type.model_class
    @class_name = @result_type.model_name
  end

  protected

  def klass= klass
    @klass = klass
    @class_name = klass.to_s
  end

  def class_name= name
    @class_name = name
    @klass = name.constantize rescue nil
  end

  def object= obj
    klass = (@object = obj).class
  end

end

