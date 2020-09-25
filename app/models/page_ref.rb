require 'net/http'

# A PageRef is a record for storing the Mercury (nee Readability) summary of a Web page.
# Besides storing the result of the query (which, after all, could be re-instantiated at any time)
# the class deals with multiple URLs leading to the same page. That is, since Mercury extracts a
# canonical URL, many URLs could lead to that single referent.
class PageRef < ApplicationRecord
  include Taggable # Can be tagged using the Tagging model
  include Collectible
  # Referrable page refs are referred to by, e.g., a glossary entry for a given concept
  include Referrable

  # The picurl attribute is handled by the :picture reference of type ImageReference
  picable :picurl, :picture

  has_many :aliases, :dependent => :destroy

  # The associated recipe page maintains the page's content in a parsed form
  belongs_to :recipe_page, :dependent => :destroy

  # We track attributes from Gleanings and MercuryResult except URL
  include Trackable
  attr_trackable :url, :domain, :title, :date_published, :author, :description, :rss_feeds, :recipe_page

  # The associated Gleaning keeps the PageRef's content by default, with backup by MercuryResults
  def content
    gleaning&.content_if_ready || mercury_result.content_if_ready
  end

  def content= val
    gleaning&.content = val
  end

  # The site specifies material to be removed from the content
  def trimmed_content
    SiteServices.new(site).trim_recipe(content) if content_ready?
  end

  def self.mass_assignable_attributes
    super + %i[ kind title lead_image_url description ]
  end

  validates_uniqueness_of :url

  validates_each :url do |pr, attr, value| # "'#{pr.url}' (PageRef ##{pr.id}) is not a valid URL"
    unless pr.good? || validate_link(pr.url, %w{ http https }) # Is it a valid URL?
      message = pr.errors.generate_message(:url, :invalid).html_safe
      pr.errors.add(:link, message) unless pr.errors.added? :link, message # Seems to happen sometimes...
    end
  end

  include Backgroundable
  backgroundable

  # Has an associated Gleaning record for a more frontal attack
  if Rails::VERSION::STRING[0].to_i < 5
    belongs_to :gleaning, dependent: :destroy
  else
    belongs_to :gleaning, optional: true, dependent: :destroy
    belongs_to :mercury_result, optional: true, dependent: :destroy
  end
  delegate :results_for, :to => :gleaning
  
  def gleaned?
    gleaning&.good?
  end

  # attr_accessible *@@mercury_attributes, :description, :link_text, :gleaning, :kind,
                  # :error_message, :http_status, :errcode,
                  # :recipes, :sites # Entities that uniquely refer to this pageref

  unless method_defined? :"link?"
    enum kind: [ :link, :recipe, :site, :referrable, :about, :article, :news_item, :tip, :video, :home_page, :product, :offering, :event]
  end

  def kind_as_fixnum
    PageRef.kinds[kind]
  end

  # Provides access to PageRefs of a particular named kind, denoted by either symbol or integer
  scope :of_kind, -> (kind) {
    # TODO: Rails 5 supports both string and fixnum kinds directly
    kind.is_a?(Integer) ? where(kind: kind) : where(kind: PageRef.kinds[kind])
  }

  has_many :recipes, :dependent => :nullify # , foreign_key: 'page_ref_id'
  accepts_nested_attributes_for :recipes
  has_many :sites, :dependent => :nullify # , foreign_key: 'page_ref_id'

  # alias_method :host, :domain
  def host
    domain
  end

  # The site for a page_ref is the Site object with the longest root matching the canonical URL
  belongs_to :site, autosave: true

  has_many :referments, :as => :referee, :dependent => :destroy
  has_many :referents, :through => :referments, inverse_of: :page_refs

  before_save do |pr|
    if pr.url_changed?
      alias_for pr.url, true      # Create a new gleaning or relaunch the old one
    end
  end

  after_create { |pr| pr.request_attributes :url } # Need to launch after creation because, somehow, a new url doesn't count as changed

=begin
  after_save do |pr|
    if pr.url.present? && !(pr.site_id || pr.site)
      puts "Find/Creating Site for PageRef ##{pr.id} w. url '#{pr.url}'"
      unless pr.site = Site.find_by(page_ref_id: id)
        pr.site = Site.find_or_create_for pr.url
        pr.site.page_refs << self
        pr.update_attribute :site_id, pr.site.id
      end
    end
    # pr.bkg_launch true if pr.saved_change_to_url?
  end

  def site
    super || (self.site = Site.find_or_build_for url)
  end
=end

  # All other PageRefables refer to a separate PageRef, but we're our own page_ref
  def page_ref
    self
  end

  # Ask gleaning and mercury_result for attributes
  def adopt_dependencies
    super if defined? super
    # After everything has settled down, we can extract our attributes
    accept_attributes gleaning.ready_attribute_values
    # Note that if we got an attribute from the Gleaning, we no longer need it from MercuryResult
    accept_attributes mercury_result.ready_attribute_values
  end

  # We attempt to drive MercuryResult and Gleaning to completion, then adopt the URLs derived therefrom,
  # in the expectation that other attributes will be extracted from the two separately.
  def perform
    mercury_result.ensure_attributes # Block until mercury_result has completed and accepted its attributes
    if mercury_result.good? # All is well
      accept_url mercury_result.url if mercury_result.url_ready?
      if mercury_result.new_aliases_ready? && mercury_result.new_aliases.present?
        new_aliases = mercury_result.new_aliases.collect {|url| Alias.indexing_url url }
        # Create a new alias on this page_ref for every derived alias that isn't already in use
        (new_aliases - aliases.pluck(:url)).each { |new_alias| alias_for new_alias, true }
      end
    elsif mercury_result.bad?
      errors.add :url, "can\'t be accessed by Mercury: #{mercury_result.errors[:base]}"
    end
    self.http_status = mercury_result.http_status

    gleaning.ensure_attributes # Block until gleaning has completed and accepted its attributes
    if gleaning.good?
      accept_url gleaning.url if gleaning.url_ready?
    elsif gleaning.bad?
      errors.add :url, "can\'t be gleaned: #{gleaning.errors[:base]}"
    end

    if errors[:url].present?
      url_errors = errors[:url].join "\n"
      if relaunch?
        raise url_errors # ...to include the errors and relaunch
      else
        errors.add :base, url_errors # ...to simply include the errors in the record
      end
    end

    if !errors.any? && recipe_page_needed?
      build_recipe_page unless recipe_page
      accept_attribute :recipe_page, recipe_page
      recipe_page.request_attributes :content
    end
  end

  def after job=nil
    self.error_message = errors[:base].join "\n" # Persist the errors before (possibly) saving the record
    super
  end

  # We relaunch the job on errors, unless there's a permanent HTTP error
  def relaunch?
    errors.present? && ![
        400, # Bad Request
        401, # Unauthorized
        403, # Forbidden
        # 404, Not Found
        414, # URI Too Long
        # 500 Internal Server Error
    ].include?(http_status)
  end

  # The indexing_url is a simplified url, as stored in an Alias
  def indexing_url
    @indexing_url ||= Alias.indexing_url url
  end

  # Will this page_ref be found when looking for a page_ref of the given url?
  # (unlike #alias_for, it checks the url for a match before hitting the aliases)
  def answers_to? qurl
    Alias.urleq(qurl, url) || alias_for?(qurl)
  end

  # Find the alias associated with the given url, optionally building one
  def alias_for url, assert=false
    iu = Alias.indexing_url(url)
    aliases.find { |al| al.url == iu } || (assert && self.aliases.build(url: iu))
  end

  # Test whether there's an existing alias
  def alias_for? url
    aliases.map(&:url).any? { |alurl| Alias.urleq url, alurl }
  end

  def elide_alias url
    if al = alias_for(url)
      aliases.delete al
    end
    url
  end

  def table
    self.arel_table
  end

  # Lookup a PageRef by resort to the Alias table
  def self.find_by_url url
    # self.joins(:aliases).find_by Alias.url_query(url)
    Alias.includes(:page_ref).find_by_url(url)&.page_ref
  end

  # This is the key maintainer of URL consistency and uniqueness
  # PageRef.fetch: provide THE ONE PageRef corresponding to the given url,
  #   whether an existing one, or a newly-built one. Its URL will be in the
  #   canonical form (eliding the target)
  # String, PageRef => PageRef; nil => nil
  # Return a (possibly newly-created) PageRef on the given URL
  # NB Since the derived canonical URL may differ from the given url,
  # the returned record may not have the same url as the request
  def self.fetch url_or_page_ref
    # Enabling "fetch" of existing page_ref
    return url_or_page_ref if url_or_page_ref.is_a?(PageRef)
    # (self.find_by_url(url_or_page_ref) || self.build_by_url(url_or_page_ref)) if url_or_page_ref.present?
    if url_or_page_ref.present?
      standardized_url = PageRef.standardized_url url_or_page_ref
      self.find_by_url(standardized_url) || self.new(url: standardized_url)
    end
  end

  def self.standardized_url url
    url.sub /\#[^#]*$/, '' # Elide the fragment for purposes of storage
  end

  # Assigning a new url has several side effects:
  # * initializing or finding the corresponding site
  # * clearing http_status and virginizing the PageRef in anticipation of launching it (when/if saved)
  # * ensuring the existence of virginized MercuryResult and Gleaning associates
  def url= new_url
    new_url = self.class.standardized_url new_url
    return if new_url == url
    super new_url # Heading for trouble if url wasn't unique
    @indexing_url = nil # Clear the memoized indexing_url
    self.http_status = nil # Reset the http_status
    self.site = Site.find_or_build_for self
    self.kind = :site if site&.page_ref == self # Site may have failed to build
    request_attributes :url # Trigger gleaning and mercury_result
    attrib_ready! :url # Has been requested but is currently ready
  end

  # Before assigning a url and possibly triggering an error, check to see how it will play out
  # If provided with a block, call it with an appropriate error message
  # There are three checks here:
  # 1) check that it's a well-formed URL
  # 2) that it actually changes the url attribute
  # 3) that none of the existing aliases covers it (so it won't generate a non-unique alias)
  # 4) that it's unique across PageRefs
  # 5) that no OTHER aliases map to it
  def acceptable_url? new_url
    if new_url.blank? || !(new_url = valid_url new_url, url)
      yield 'is not a valid url' if block_given?
      return false
    end

    standardized_url = PageRef.standardized_url new_url
    return false if standardized_url == url # Not an error, but redundant

    return true if alias_for?(new_url)

    if PageRef.where(url: standardized_url).exists? || Alias.find_by_url(new_url)
      # There's an existing alias--not one of ours--which constitutes a conflict: no good
      yield "'#{standardized_url}' is already in use elsewhere." if block_given?
      false
    else
      true
    end
  end

  # Provide a relation for entities that match a string
  def self.strscopes matcher
    ar = self.arel_table[:domain].matches matcher
    [
        (block_given? ? yield() : self).where(ar)
    ]
  end

  # Associate this page_ref with the given referent.
  # NB: had better be a ReferrableReferent or subclass thereof
  def assert_referent rft
    return unless rft
    unless referents.exists?(id: rft.id)
      self.referents << rft
      # Saving the page_ref appears to be the only way to ensure that the list of referents is current
      save
    end
  end

  # Accept the standardized form of the url only, but only if it's valid
  def accept_url url
    accept_attribute :url, self.class.standardized_url(url) if url.present? && acceptable_url?(url)
    # self.write_attribute :url, url
  end

  # Accept attribute values extracted from a page:
  # 1: hand them off to the gleaning
  # 2: adopt them back from there
  def adopt_extractions extraction_params={}
    if extraction_params.present?
      build_gleaning unless gleaning
      # Declare the attributes needed w/o launching to glean
      # NB: we take ALL proffered attributes, not just those that are priorly needed
      # gleaning.attribs_needed! *extraction_params.keys
      gleaning.accept_attributes extraction_params

      # attribs_needed! *extraction_params.keys
      accept_attributes extraction_params
    end
  end
  
  private

  # In the course of taking a request for newly-needed attributes, fire
  # off dependencies from gleaning and mercury_result
  def request_dependencies *newly_needed
    build_gleaning if !gleaning
    gleaning.request_attributes *(Gleaning.tracked_attributes & newly_needed)
    # Translate from our needed attributes to those provided by mercury_result
    build_mercury_result if !mercury_result
    mercury_result.request_attributes *(MercuryResult.tracked_attributes & newly_needed)
  end

  end
