class PageRefDecorator < CollectibleDecorator
  # include Templateer
  # delegate_all

  def attribute_for what
    case default = super
      when :image
        :picurl
      else
        default
    end
  end

  # What the attributes of a site "really" represent
  def attribute_represents what
    case what.to_sym
      when :image
        :picurl
      when :page_ref_kind, :type
        nil
      else
        super
    end
  end

=begin
  def name
    # The name by which the reference is referred to is either
    # 1) the link_text of the reference (preferred), or
    # 2) the name of the canonical expression of the reference's first referent
    if object.title.present?
      object.title
    elsif object.is_a?(Referrable) && object.referents.first
      object.referents.first.name
    end
  end
=end

  def human_name plural=false, capitalize=true
    name = object.kind.humanize
    name = name.pluralize if plural
    capitalize ? name : name.downcase
  end

  def title
    (object.title if object.title.present?) || (url if url.present?) || '<unknown title>'
  end

  def image
    object.picurl
  end

  def image=img
    object.picurl = img
  end

  def external_link
    url
  end

  # The name for the decorator devolves to the PageRef's type, since
  # we may be dealing with a subclass of PageRef
  def class_name
    type
  end

  def eligible_tagtypes
    ([ :Ingredient, :Genre, :Occasion, :Dish, :Process, :Tool, :Course, :Diet ] + super).uniq
  end

end