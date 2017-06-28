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

=begin
  def present_field_wrapped what=nil
    h.content_tag :span,
                  present_field(what),
                  class: 'hide-if-empty'
  end
=end

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
    (super + [ :description, :title, :site, (:found_by if @decorator.first_collector) ]).compact.uniq
  end

  def card_aspect which
    label = nil
    whichsym = which.to_sym
    whichstr = which.to_s.downcase
    contents =
        case whichsym
          when :Tool, :Process, :Dish, :Course, :Diet, :Author, :Occasion, :Genre, :Source, :Ingredient, :Misc
            denotation = which.to_s.downcase
            tags = decorator.send "visible_#{whichstr}_tags" # visible_tags :tagtype => :Dish
            label = field_label_counted decorator.send("#{whichstr}_tags_label"), tags.count
            entity_links tags, joinstr: ' | '
          when :List # Lists it appears under
            lists_with_status = ListServices.associated_lists_with_status decorator
            label = field_label_counted 'AS SEEN IN TREASURY', lists_with_status.count
            list_lists_with_status lists_with_status
          when :site
            h.homelink(decorator.object.site) if decorator.object.respond_to? :site
            # h.link_to decorator.sourcename, decorator.sourcehome, class: 'tablink' if decorator.respond_to? :sourcehome
          when :notes
            decorator.notes if decorator.respond_to? :notes
          else
            return super
          end
    [ label, contents ]
  end

  def card_avatar options={}
    # The card avatar is an image that goes either to the original entity (single click) or to edit the image (dbl-click)
    if (img = image_from_decorator(decorator)) && options[:onlinks]
      # Include invisible links to open the entity on click and edit the picture on double-click
      img <<
          link_to('',
                  decorator.external_link,
                  {
                      data: {report: touchpath(decorator)}.compact,
                      target: '_blank',
                      title: 'Open Original',
                      class: 'clicker'
                  }.compact) if decorator.respond_to?(:external_link)
      img <<
          link_to_dialog('',
                         polymorphic_path([:editpic, decorator]),
                         class: 'dblclicker') if permitted_to?(:update, decorator.object)
      content_tag :div, img, class: 'onlinks'
    else
      img
    end
  end

  # By default, show the card if there's an avatar OR a backup avatar
  def card_show_avatar
    (href = decorator.imgdata).present? ? href : h.image_path(decorator.fallback_imgdata)
  end

  def card_avatar_accompaniment
    if collector = decorator.first_collector
      card_aspect_enclosure :found_by,
                            h.labelled_avatar(collector.decorate),
                            'Found By'
    end
  end

  # Present the card column in which is embedded the avatar for the entity, and that of is first collector, if any
  def card_avatar_column
    content = card_avatar(onlinks: true)
    if acc = card_avatar_accompaniment
      content << acc
    end
    content_tag :div,
                content,
                { class: 'stamp avatar card-column', style: ('display:none;' if content.empty?) } #.compact
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
