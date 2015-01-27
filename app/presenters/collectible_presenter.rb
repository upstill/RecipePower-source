class CollectiblePresenter

  attr_accessor :picfallback, :modal, :tagfields
  attr_writer :buttons

  def initialize decorator, template
    @template = template
    @decorator = decorator
    @tagfields = [
        ['Lists', "Listed In"],
        "Ingredient_tags",
        ["Role_tags", "Produces"],
        "Genre_tags",
        "Occasion_tags",
        "Process_tags",
        "Tool_tags",
        "Other Tag_tags"
    ]
  end

  def h
    @template
  end

  def picdata
    pd = @decorator.picdata
    pd.blank? ? picfallback : pd
  end

  def pic_class
    modal ? "col-md-4 col-sm-6" : "col-lg-2 col-md-3 col-sm-3"
  end

  def divclass
    if picdata.blank?
      modal ? "col-md-8 col-sm-6" : "col-lg-5 col-md-6 col-sm-7"
    else
      modal ? "col-md-12 col-sm-12" : "col-lg-5 col-md-7 col-sm-12"
    end
  end

  def picdiv
    unless picdata.blank?
      h.content_tag :div,
                  h.safe_image_div(@decorator, picdata, class: "resource-element pic"),
                  class: pic_class
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

  def picfallback
    @picfallback ||= (site = (@decorator.site rescue nil)) ? site.picdata : nil
  end

end