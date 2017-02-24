require './lib/results.rb'

class Gleaning < ActiveRecord::Base
  include Backgroundable

  backgroundable :status

  require 'finder_services.rb'
  belongs_to :entity, :polymorphic => true

  attr_accessible :entity, :results, :http_status, :err_msg

  attr_accessor :decorator # Decorator corresponding to entity

  serialize :results

  delegate :result_for, :results_for, :labels, :to => :results

  # Crack a url (or the home page for a decorator) for the information denoted by the set of labels
  def self.glean url_or_decorator, *labels
    if url_or_decorator.is_a? String
      (gleaning = self.new).go url_or_decorator
    elsif url_or_decorator.object.respond_to? :gleaning
      url = url_or_decorator.pageurl
      url_or_decorator.glean!
      (gleaning = url_or_decorator.gleaning).go url, (url_or_decorator.site if url_or_decorator.respond_to?(:site))
    end
    gleaning
  end

  def perform
    go entity.decorate.url, (entity.site if entity.respond_to?(:site))
  end

  # Execute a gleaning on the given url, RIGHT NOW (maybe in an asynchronous execution, maybe not)
  def go url, site=nil
    bkg_execute do
      self.err_msg = ''
      self.http_status = 200
      self.results = FinderServices.glean(url, site)  { |msg|
        # Handle errors
        self.err_msg = msg
        # We assume the first three-digit number is the HTTP status code
        self.http_status = (m=msg.match(/\b\d{3}\b/)) ? m[0].to_i : (401 if msg.match('redirection forbidden:'))
      }
      entity.decorate.after_gleaning(self) if entity.decorate.respond_to?(:after_gleaning)
      self.results # Returning success indicator
    end
  end

  def error(job, exception)
    errors.add 'url', "analyzing page: #{exception}."
    bad!
    save
  end

  def options_for label
    (results && results[label]) ? results[label].map(&:out).flatten.uniq : []
  end

  def attributes= attrhash
    return unless entity.respond_to? :site
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
    self.results ||= Results.new *results_hash.keys
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
    end if results
    result
  end

  def extract1 label
    if results && result = (results[label] || []).map(&:out).flatten.first
      yield(result)
    end
  end

  private

  # Declare success on a label/value pair by voting up the corresponding finder
  def hit_on site, label, value
    if results && value.present?
      # Vote up each finder that produces this value
      results[label].each do |result|
        if result.out.include? value
          site.hit_on_finder *result.finderdata.slice(:label, :selector, :attribute_name).values
        end
      end
    end
  end
end
