require './lib/results.rb'

class Gleaning < ApplicationRecord
  include Backgroundable

  backgroundable :status

  after_create { |gl| gl.bkg_launch }

  require 'finder_services.rb'

  has_one :page_ref
  has_one :site, :through => :page_ref

  # attr_accessible :results, :http_status, :err_msg, :entity_type, :entity_id, :page_ref # , :decorator # Decorator corresponding to entity

  serialize :results, Results

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
      url_or_decorator.bkg_land
      (gleaning = url_or_decorator.gleaning).go url, (url_or_decorator.site if url_or_decorator.respond_to?(:site))
    end
    gleaning
  end

  def perform
    go page_ref.url, site
  end

  # Execute a gleaning on the given url, RIGHT NOW (maybe in an asynchronous execution, maybe not)
  def go url, site=nil
    # bkg_execute do
      self.err_msg = ''
      self.http_status = 200
      begin
        self.results = FinderServices.glean url, site
      rescue Exception => msg
        # Handle errors
        # msg.message
        # msg.backtrace
        breakdown = FinderServices.err_breakdown url, msg
        self.err_msg = breakdown[:msg] + msg.backtrace.join("\n")
        self.http_status = breakdown[:status]
        # errors.add :url, " #{url} failed to glean (http_status #{http_status}): #{msg}"
        raise msg
      end
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
    bkg_land # Ensure that gleaning has occurred, whether synch. or asynch.
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
