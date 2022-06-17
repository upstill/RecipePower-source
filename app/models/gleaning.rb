require './lib/results.rb'

# A Gleaning object stores the result of examining a page via Nokogiri--the page linked by the associated page_ref
class Gleaning < ApplicationRecord
  include Backgroundable

  backgroundable :status

  require 'finder_services.rb'

  has_one :page_ref, :dependent => :nullify, :autosave => true
  has_one :site, :through => :page_ref, :autosave => true
  accepts_nested_attributes_for :page_ref
  accepts_nested_attributes_for :site

  # These are virtual attributes we can get from the results, as defined by Finders with the corresponding labels.
  # (Commented vas here have been subsumed into attributes of the Gleaning)
  delegate :uri, :uris,
           :titles, # :title,
           :descriptions, # :description,
           :image, :images,
           # :author, :authors,
           :author_name, :author_names,
           # :author_link, :author_links,
           # :tag, :tags,
           # :site_name, :site_names,
           :rss_feed, :rss_feeds,
           # :content, :contents,
           :to => :results

  def self.mass_assignable_attributes
    [ { :page_ref_attributes => (PageRef.mass_assignable_attributes << :id ) }]
  end

  # attr_accessible :results, :http_status, :err_msg, :entity_type, :entity_id, :page_ref # , :decorator # Decorator corresponding to entity

  serialize :results, Results
  
  include Trackable
  # "URI", "Image", "Title", "Author Name", "Author Link", "Description", "Tags", "Site Name", "RSS Feed", "Author", "Content"
  attr_trackable :url, :picurl, :title, :author, :author_link, :description, :tags, :site_name, :rss_feeds, :content, :http_status

  # Define a mapping from Result label to the attribute that takes it on
  def self.attribute_for_label label
    case label
    when "URI"
      :url
    when "Image"
      :picurl
    when "Author Name"
      :author
    when 'RSS Feed'
      :rss_feeds
    else
      label.downcase.sub(' ', '_').to_sym
    end
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

  def drive_dependencies minimal_attributes=needed_attributes, overwrite: false, restart: false
    needed_by_super = defined?(super) && super
    if needed_attributes.present?
      self.results = nil
      true
    else
      needed_by_super
    end
  end

  def adopt_dependencies synchronous: false, final: false
    return if bad? || results.empty?
    results.labels.each do |label|
      next unless attrname = Gleaning.attribute_for_label(label)
      next unless attrib_open?(attrname)
      if label != 'RSS Feed' # RSS Feeds are satisfied even without finding anything
        next if results[label].empty?
      end
      value =
          case label
          when 'RSS Feed'
            results&.results_for 'RSS Feed'
          when 'Tags', 'Author'
            results&.results_for(label).uniq.join(', ')
          else
            results&.result_for label
          end
      self.send :"#{attrname}=", value
    end
    self.content_needed = false if final # It is a non-fatal error if content can't be extracted
  end

  def relaunch_on_error?
    http_status_needed || !permanent_http_error?(http_status)
  end

  # Execute a gleaning on the page_ref's url
  def perform
    self.err_msg = ''
    self.http_status = 200
    begin
      self.results = FinderServices.glean page_ref.url, page_ref.site
    rescue Exception => msg
      breakdown = FinderServices.err_breakdown page_ref.url, msg
      self.err_msg = breakdown[:msg] + msg.backtrace.join("\n")
      self.http_status = breakdown[:status]
      errors.add :url, breakdown[:msg]
      exc = Exception.new breakdown[:msg]
      exc.set_backtrace msg.backtrace
      raise exc # msg, breakdown[:msg] if dj
    end
  end

  def options_for label
    (results && results[label]) ? results[label].map(&:out).flatten.uniq : []
  end

=begin
  # Access the results by label; singular => return first result, plural => return all
  def method_missing namesym, *args
    results&.send namesym, *args
  end
=end

  # Add results (presumably from a new finder) to the results in a Gleaning
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

  # Record the fact that a Finder found content on a page
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
