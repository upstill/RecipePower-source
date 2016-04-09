class Gleaning < ActiveRecord::Base
  require 'site_services.rb'
  belongs_to :entity, :polymorphic => true

  attr_accessible :entity, :results

  attr_accessor :decorator # Decorator corresponding to entity

  serialize :results

  after_initialize :doit

  def doit
    @decorator = entity.decorate
    begin
      unless results
        self.results = SiteServices.new(entity.site).gleaning_results @decorator.url
      end
    rescue Exception => e
      errors.add 'url', "analyzing page '#{@decorator.url}': #{e}."
      return {}
    end
  end
end
