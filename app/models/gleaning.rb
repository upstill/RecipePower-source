class Gleaning < ActiveRecord::Base
  require 'site_services.rb'
  belongs_to :entity, :polymorphic => true

  attr_accessible :entity, :results, :status

  enum status: [ :virgin, :pending, :processing, :good, :bad ]

  attr_accessor :decorator # Decorator corresponding to entity

  serialize :results

  def perform
    if virgin? || pending?
      # Lock during processing
      processing!
      save
      url = entity.decorate.url
      begin
        if self.results = SiteServices.new(entity.site).gleaning_results(url)
          good!
        else
          bad!
        end
      rescue Exception => e
        errors.add 'url', "analyzing page '#{url}': #{e}."
        bad!
      end
      save
    end
  end

  # Fire off worker process to glean results, if needed
  def fire force=false
    if virgin? || (force && !(pending? || processing?))
      pending!
      save
      Delayed::Job.enqueue self
    end
    pending?
  end

  # Glean results asynchronously, returning only when status is definitive (good or bad)
  def ensure force=false
    if virgin? || pending? # Run the scrape process right now
      perform
    elsif processing? # Wait for scraping to return
      until !processing?
        sleep 1
        reload
      end
    elsif force
      pending!
      perform
    end
    good?
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

  # Access the results by name
  def method_missing namesym_or_str, *args
    namestr = namesym_or_str.is_a?( Symbol) ? namesym_or_str.to_s.gsub('_',' ').titleize : namesym_or_str
    puts namestr + ' results.'
    (results && results[namestr] && results[namestr].collect(&:out).flatten.uniq) || []
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

  def extract_unique *labels
    result = ''
    labels.each do |label|
      index = 0
      (results[label] || []).map(&:out).flatten.uniq.each do |str|
        result += yield(str, index) || ''
        index += 1
      end
    end
    result
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
