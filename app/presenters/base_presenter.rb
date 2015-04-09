class BasePresenter
  require 'redcarpet'

  attr_accessor :viewer_id

  def initialize(object, template, viewer_id = nil)
    @object = object
    @template = template
    @viewer_id = viewer_id
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