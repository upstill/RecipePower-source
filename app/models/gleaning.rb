require './lib/results.rb'

# A Gleaning object stores the result of examining a page via Nokogiri--the page linked by the associated page_ref
class Gleaning < ApplicationRecord
  include Backgroundable

  backgroundable :status

  require 'finder_services.rb'

  has_one :page_ref, :dependent => :nullify
  has_one :site, :through => :page_ref

  # attr_accessible :results, :http_status, :err_msg, :entity_type, :entity_id, :page_ref # , :decorator # Decorator corresponding to entity

  serialize :results, Results

  attr_accessor :needs # A list of labels to satisfy when gleaning

  # Keeps a non-persistent list of labels to satisfy for the gleaning
  def needs
    @needs ||= []
  end

  # ------------- safe delegation to (potentially non-existent) results
  def result_for label
    val = results&.result_for label
    # If passed a block, call the block on the value
    yield(val) if val && block_given?
    val
  end

  def results_for label
    results&.results_for label
  end

  def report_for label
    results&.report_for label
  end

  def labels
    results&.labels || []
  end

  def bkg_launch force=false
    ffc = site&.finder_for 'Content'
    force ||= ffc && (updated_at < ffc.updated_at)  # Launch if we're older than the :content finder
    super(force) if defined?(super)
  end

  # Execute a gleaning on the page_ref's url
  def perform
    self.err_msg = ''
    self.http_status = 200
    begin
      self.results = FinderServices.glean page_ref.url, page_ref.site, *needs
    rescue Exception => msg
      breakdown = FinderServices.err_breakdown page_ref.url, msg
      self.err_msg = breakdown[:msg] + msg.backtrace.join("\n")
      self.http_status = breakdown[:status]
      errors.add :url, breakdown[:msg]
      raise breakdown[:msg] if dj
    end
  end

  def options_for label
    (results && results[label]) ? results[label].map(&:out).flatten.uniq : []
  end

  # Access the results by label; singular => return first result, plural => return all
  def method_missing namesym, *args
    results&.send namesym, *args
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

=begin
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
=end

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
