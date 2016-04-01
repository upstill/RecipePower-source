class CollectiblePresenter < BasePresenter

  attr_accessor :modal
  attr_writer :buttons

  def h
    @template
  end

  def pic_class
    modal ? "col-md-4 col-sm-6" : "col-lg-2 col-md-3 col-sm-3"
  end

  def divclass
    if @decorator.imgdata.blank?
      modal ? "col-md-8 col-sm-6" : "col-lg-5 col-md-6 col-sm-7"
    else
      modal ? "col-md-12 col-sm-12" : "col-lg-5 col-md-7 col-sm-12"
    end
  end

  def title
    unless modal
      h.content_tag :p, @decorator.title, class: "resource-element title"
    end
  end

  def description
    h.content_tag :p, @decorator.description, class: "resource-element subtitle"
  end

  def buttons
    @buttons || h.collectible_buttons_panel(@decorator)
  end

  def present_field_wrapped what=nil
    h.content_tag :span,
                  present_field(what),
                  class: "hide-if-empty"
  end

  def field_value what=nil
    return form_authenticity_token if what && (what == 'authToken')
    if val = @decorator && @decorator.extract(what)
      val.html_safe
    end
  end

  def present_field what=nil
    field_value(what) || %Q{%%#{(what || '').to_s}%%}.html_safe
  end

  def field_count what
    @decorator && @decorator.respond_to?(:arity) && @decorator.arity(what)
  end

  def present_field_label what
    label = what.sub '_tags', ''
    case field_count(what)
      when nil, false
        "%%#{what}_label_plural%%"+"%%#{what}_label_singular%%"
      when 1
        label.singularize
      else
        label.pluralize
    end
  end

  def card_aspects which_column=nil
      (super + [ :tags, (:found_by if @decorator.first_collector) ]).compact.uniq
  end

end

class ListPresenter < CollectiblePresenter

end
