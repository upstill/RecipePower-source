class Gleaning < ActiveRecord::Base
  require 'site_services.rb'
  belongs_to :entity, :polymorphic => true

  attr_accessible :entity, :page_tags

  attr_accessor :decorator # Decorator corresponding to entity

  serialize :page_tags

  after_initialize :doit

  def doit
    @decorator = entity.decorate
    begin
      unless page_tags
        self.page_tags = PageTags.new @decorator.url, entity.site, true, true
      end
    rescue Exception => e
      errors.add 'url', "analyzing page '#{@decorator.url}': #{e}."
      return {}
    end
  end
end
