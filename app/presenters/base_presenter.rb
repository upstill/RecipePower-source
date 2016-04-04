class BasePresenter
  require 'redcarpet'
  include CardPresentation

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
    # @display_services = DisplayServices.new viewer, @object
  end

  # Does this presenter have an avatar to present on cards, etc?
  def card_avatar?
    decorator.imgdata.present?
  end

  def card_video
    nil
  end

  def card_video?
    card_video.present?
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

