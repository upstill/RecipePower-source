class BasePresenter
  require 'redcarpet'

  attr_reader :viewer, :decorator

  def initialize decorator_or_object, template, viewer
    if decorator_or_object.is_a?(Draper::Decorator)
      @decorator, @object = decorator_or_object, decorator_or_object.object
    else
      @object = decorator_or_object
      @decorator = (decorator_or_object.decorate if decorator_or_object.respond_to? :decorate)
    end
    @template = template
    @viewer = viewer
  end

private

  def self.presents(name)
    define_method(name) do
      @object
    end
  end

  def h
    @template
  end

  def markdown(text)
    renderer = Redcarpet::Render::HTML.new(:hard_wrap => true, :filter_html => true, :autolink => true)
    markdown = Redcarpet::Markdown.new(renderer)
    markdown.render(text).html_safe
  end
  
  def method_missing(*args, &block)
    @template.send(*args, &block)
  end
end

class CardPresenter < BasePresenter

  def card_avatar
    img = card_avatar_link
    img = card_avatar_fallback if img.blank?
    card_object_link image_with_error_recovery(img, class: "media-object fixed-width", alt: path_to_asset(card_avatar_fallback) )
  end

  # Take the opportunity to wrap the content in a link to the presented object
  def card_object_link content
    content # h.link_to_if(user.url.present?, content, user.url)
  end

  def card_avatar_link
    decorator.imglink if decorator.respond_to?(:imglink)
  end

  # Image to be shown in the absence of an avater
  def card_avatar_fallback
    "NoPictureOnFile.png"
  end

  def card_header
    editlink = collectible_buttons_panel @decorator,
                                         :button_size => "xs",
                                         :edit_button => response_service.admin_view?
    content_tag :h2, "#{card_header_content}&nbsp;#{editlink}".html_safe, class: "media-heading"
  end

  def card_header_content
    @decorator.title
  end

  def card_aspect_enclosure which, contents, label=nil
    label ||= which.to_s.capitalize.tr('_', ' ') # split('_').map(&:capitalize).join
    content_tag( :tr,
                 content_tag( :td, content_tag( :h4, label), style:"padding-right: 10px; vertical-align:top; text-align: right" )+
                     content_tag( :td, contents.html_safe, style: "vertical-align:top; padding-top:11px" ),
                 class: which.to_s
    ) unless contents.blank?
  end

  def card_aspect_editor which
    card_aspect_enclosure which, with_format("html") { render "form_#{which}", user: viewer }
  end

  def card_aspect_editor_replacement which
    if repl = self.aspect_editor(which)
      [ card_aspect_selector(which), repl ]
    end
  end

  def card_aspect_selector which
    "tr.#{which}"
  end

  def card_aspect_replacement which
    if repl = aspect(which)
      [ card_aspect_selector(which), repl ]
    end
  end

  def card_aspect_rendered which
    label, contents = card_aspect which
    card_aspect_enclosure which, contents, label
  end

  # This method is overridden by subclasses to define elements of the display as a label/content pair
  def card_aspect which

  end

  # Provide a list of aspects for display in the entity's panel, suitable for passing to card_aspect
  def card_aspects
  [ ]
  end

end
