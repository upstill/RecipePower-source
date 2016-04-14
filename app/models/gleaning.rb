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

  def options_for label
    (results && results[label]) ? results[label].map(&:out).flatten.uniq : []
  end

  def attributes= attrhash
    site = entity.site
    attrhash.each do |label, value|
      hit_on site, label, value
    end
  end

  def method_missing namesym, *args
    namestr = namesym.to_s
    if namestr.match /\=$/
      # Assign virtual attribute, which means voting for the named string
      x=2
    else
      case namesym
        when :Description, :description
          nil
      end
    end
  end

  # Add results (presumably from a new finder) to the results in a gleaning
  def assimilate_finder_results results_hash
    do_save = false
    results_hash.each do |key, results_arr|
      results_arr.each do |proposed|
        # Either modify an existing result in the gleaning, or append this one
        unless (results[key] ||= []).detect { |my_result|
          my_result.finderdata.slice(:selector, :attribute_name).values ==
          proposed.finderdata.slice(:selector, :attribute_name).values
        }
          results[key] << proposed
          do_save = true
        end
      end
    end
    save if do_save
    do_save || true # Return a boolean indicating whether the finder made a difference
  end

  private

  # Declare success on a label/value pair by voting up the corresponding finder
  def hit_on site, label, value
    if value.present?
      # Vote up each finder that produces this value
      results[label].each do |result|
        if result.out.include? value
          site.hit_on_finder *result.finderdata.slice(:label, :selector, :attribute_name).values
        end
      end
    end
  end
end
