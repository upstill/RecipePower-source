class BasePresenter
  require 'redcarpet'
  def initialize(object, template)
    @object = object
    @template = template
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