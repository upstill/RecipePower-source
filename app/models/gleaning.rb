class Gleaning < ActiveRecord::Base
  require 'finder_services.rb'
  belongs_to :entity, :polymorphic => true

  attr_accessible :entity, :results, :status

  enum status: [ :virgin, :pending, :processing, :good, :bad ]

  attr_accessor :decorator # Decorator corresponding to entity

  serialize :results

  delegate :result_for, :results_for, :labels, :to => :results

  # Crack a url (or the home page for a decorator) for the information denoted by the set of labels
  def self.glean url_or_decorator, *labels
    if url_or_decorator.object.is_a? Linkable
      url = url_or_decorator.pageurl
      url_or_decorator.glean!
      (gleaning = url_or_decorator.gleaning).go url, url_or_decorator.site
    else
      url = url_or_decorator
      (gleaning = self.new).go url_or_decorator
    end
    gleaning
  end

  # Execute a gleaning on the given url
  def go url, site=nil, *labels
    if site.is_a? String
      labels.unshift site
      site = nil
    end
    begin
      if self.results = FinderServices.findings(url, site, *labels)
        good!
      else
        bad!
      end
    rescue Exception => e
      errors.add 'url', "analyzing page '#{url}': #{e}."
      bad!
    end
    good?
  end

  def perform
    if virgin? || pending?
      # Lock during processing
      processing!
      save
      go entity.decorate.url, entity.site
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
    decorator = entity.decorate
    (attrhash || {}).each do |label, value_or_set|
      if value_or_set.is_a? Hash
        (value_or_set = value_or_set.values).map { |value| hit_on site, label, value }
      else
        hit_on site, label, value_or_set
      end
      decorator.assert_gleaning_attribute label, value_or_set
    end
  end

  # Access the results by label; singular => return first result, plural => return all
  def method_missing namesym, *args
    namestr = namesym.to_s.gsub('_',' ').titleize
    namestr = namestr.singularize if is_plural = (namestr == namestr.pluralize)
    namestr.sub! /Rss/, 'RSS'
    puts namestr + ' results.'
    if results && results[namestr]
      list = results[namestr].collect(&:out).flatten.uniq || []
      is_plural ? list : list.first
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

  def extract_all *labels
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

  def extract1 label
    (results[label] || []).map(&:out).flatten.first do |str|
      yield(str)
    end
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
