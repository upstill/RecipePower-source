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
    # @display_services = DisplayServices.new viewer, @object
  end

  def ribbon ribbon_class=nil, name=@decorator.human_name
    return unless name.present?
    h.content_tag :div,
                  h.content_tag(:span, name),
                  class: "ribbon #{ribbon_class}"
  end

  def content
    # Individual presenters may override to present content
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

