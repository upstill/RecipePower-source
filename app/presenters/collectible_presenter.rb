class CollectiblePresenter < BasePresenter
  include CardPresentation

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
      h.content_tag :p, @decorator.title, class: 'resource-element title'
    end
  end

  def description
    h.content_tag :p, @decorator.description.html_safe, class: 'resource-element subtitle'
  end

  def buttons
    @buttons || h.collectible_buttons_panel(@decorator)
  end

  def present_field_wrapped what=nil
    h.content_tag :span,
                  present_field(what),
                  class: 'hide-if-empty'
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
    (super + [ :author, :description, :tags, :title, :lists, (:found_by if @decorator.first_collector) ]).compact.uniq
  end

  def card_aspect which
    label = nil
    contents =
        case which.to_sym
          when :author
            tags = decorator.visible_author_tags # visible_tags :tagtype => :Author
            label = field_label_counted 'author', tags.count
            entity_links tags, joinstr: ' | '
          when :tags
            taglist = decorator.visible_no_author_tags # visible_tags :tagtype_x => [ :Question, :List, :Author ]
            label = field_label_counted 'tags', taglist.count
            list_tags_for_collectible taglist, decorator
          when :lists # Lists it appears under
            lists_with_status = ListServices.associated_lists_with_status decorator
            label = field_label_counted 'AS SEEN IN TREASURY', lists_with_status.count
            list_lists_with_status lists_with_status
          when :site
            h.link_to decorator.sourcename, decorator.sourcehome, class: 'tablink' if decorator.respond_to? :sourcehome
          when :found_by
            if collector = decorator.first_collector
              h.labelled_avatar collector.decorate, onload: 'layoutMasonryOnLoad(event);'
            end
          when :notes
            decorator.notes if decorator.respond_to? :notes
          else
            return super
        end
    [ label, contents ]
  end

  def card_aspect_size which
    'card-column-xl' if (which.to_sym == :tags)
  end

  # Does this presenter have an avatar to present on cards, etc?
  def card_avatar?
    decorator.imgdata.present?
  end

  def card_avatar options={}
    img = image_from_decorator decorator, options
    if img && permitted_to?(:update, decorator.object)
      link_to_submit img,
                     polymorphic_path([:editpic, decorator.object]),
                     mode: 'modal',
                     title: 'Get Picture'
    else
      img
    end
  end

  # By default, show the card if there's an avatar OR a backup avatar
  def card_show_avatar
    (href = decorator.imgdata).present? ? href : h.image_path(decorator.fallback_imgdata)
  end

  # Entities are editable, sharable, votable and collectible from the card by default
  def editable_from_card?
    true
  end

  def edit_button
    collectible_edit_button decorator if editable_from_card?
  end

  def tools_menu
    collectible_tools_menu decorator, 'lg' if editable_from_card? || response_service.admin_view?
  end

  def sharable_from_card?
    true
  end

  def share_button
    collectible_share_button decorator, 'lg' if sharable_from_card?
  end

  def votable_from_card?
    true
  end

  def vote_buttons
    collectible_vote_buttons decorator.object, class: 'stamp votes' if votable_from_card?
  end

  def collectible_from_card?
    true
  end

  def collect_button
    collectible_collect_button decorator if collectible_from_card?
  end

end

class ListPresenter < CollectiblePresenter

end
