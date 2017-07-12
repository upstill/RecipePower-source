require './lib/results.rb'

class Gleaning < ActiveRecord::Base
  include Backgroundable

  backgroundable :status

  require 'finder_services.rb'

  has_one :page_ref
  has_one :site, :through => :page_ref

  attr_accessible :results, :http_status, :err_msg, :entity_type, :entity_id # , :decorator # Decorator corresponding to entity

  serialize :results

  # delegate :result_for, :results_for, :labels, :to => :results

  # ------------- safe delegation to (potentially non-existent) results
  def result_for label
    results.result_for(label) if results
  end

  def results_for label
    results.results_for(label) if results
  end

  def labels
    results ? results.labels : []
  end

  # Crack a url (or the home page for a decorator) for the information denoted by the set of labels
  def self.glean url_or_decorator, *labels
    if url_or_decorator.is_a? String
      (gleaning = self.new status: :processing).go url_or_decorator
    elsif url_or_decorator.object.respond_to? :gleaning
      url = url_or_decorator.pageurl
      url_or_decorator.glean!
      (gleaning = url_or_decorator.gleaning).go url, (url_or_decorator.site if url_or_decorator.respond_to?(:site))
    end
    gleaning
  end

  def perform
    go page_ref.url, site
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
      save if persisted?
      # TODO: Restore this Site functionality:
      # entity.decorate.after_gleaning(self) if entity && entity.decorate.respond_to?(:after_gleaning)
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

  # Access the results by label; singular => return first result, plural => return all
  def method_missing namesym, *args
    namestr = namesym.to_s.gsub('_',' ').titleize
    namestr = namestr.singularize if is_plural = (namestr == namestr.pluralize)
    namestr.sub! /Rss/, 'RSS'
    puts namestr + ' results.'
    bkg_sync true # Ensure that gleaning has occurred, whether synch. or asynch.
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

  def hit_on_attributes attrhash, site
    return unless results.present? && site
    attrhash.each do |label, value_or_set|
      if value_or_set.is_a? Hash
        (value_or_set = value_or_set.values).map { |value|
          hit_on_attribute label, value, site
        }
      else
        hit_on_attribute label, value_or_set, site
      end
    end
  end

  private

  def hit_on_attribute label, value, site
    if value.present? && results[label].present?
      # Vote up each finder that produces this value
      results[label].each { |result|
        site.hit_on_finder *result.finderdata.slice(:label, :selector, :attribute_name).values if result.out.include? value
      }
    end
  end
end
