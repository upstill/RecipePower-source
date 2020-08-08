class BasePresenter
  require 'redcarpet'

  attr_reader :viewer, :decorator

  def initialize decorator_or_object, template, viewer=User.current_or_guest
    if decorator_or_object.is_a?(Draper::Decorator)
      @decorator, @object = decorator_or_object, decorator_or_object.object
    else
      @object = decorator_or_object
      @decorator = (decorator_or_object.decorate if decorator_or_object.respond_to? :decorate)
    end
    @template = template
    @viewer = viewer
  end

  def ribbon ribbon_class=nil, name=@decorator.human_name
    return unless name.present?
    content = h.content_tag :div,
                  h.content_tag(:span, name),
                  class: "ribbon #{ribbon_class}"
    block_given? ? yield(content) : content
  end

  # Recipes don't have a tab on their card
  def card_label
    label = content_tag :div,
                        @decorator.human_name,
                        class: 'card-label'
    content_tag :div,
        label,
        class: 'label-rotator rotate'
  end

  # Provide the HTML presentation for the object, if any
  def html_content variant=nil
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

  # Any method missing from the presenter gets deferred to the template
  def method_missing(*args, &block)
    @template.send(*args, &block)
  end
end

