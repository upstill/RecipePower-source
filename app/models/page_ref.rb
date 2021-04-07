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
  has_one :recipe_page, :dependent => :destroy

  # We track attributes from Gleanings and MercuryResult except URL
  include Trackable
  attr_trackable :url, :domain, :title, :content, :picurl, :date_published, :author, :description, :rss_feeds, :recipe_page

  # The associated Gleaning keeps the PageRef's content by default, with backup by MercuryResults
  def content
    return gleaning.content if gleaning&.content_ready?
    return mercury_result.content if mercury_result&.content_ready?
  end

  def content= val
    gleaning&.accept_attribute :content, val
    attrib_done :content
  end

  # The site specifies material to be removed from the content
  def trimmed_content
    SiteServices.new(site).trim_recipe(content) if content_ready?
  end

  def self.mass_assignable_attributes
    super + [ :kind, :title, :lead_image_url, :description, { :site_attributes => (Site.mass_assignable_attributes << :id) } ]
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
    belongs_to :gleaning, autosave: true, optional: true, dependent: :destroy
    belongs_to :mercury_result, autosave: true, optional: true, dependent: :destroy
  end
  delegate :results_for, :to => :gleaning
  
  def gleaned?
    gleaning&.good?
  end

  # attr_accessible *@@mercury_attributes, :description, :link_text, :gleaning, :kind,
                  # :error_message, :http_status, :errcode,
                  # :recipes, :sites # Entities that uniquely refer to this pageref

  unless method_defined? :"link?"
    enum kind: [ :link, :recipe, :site, :referrable, :about, :article, :news_item, :tip, :video, :home_page, :product, :offering, :event, :recipe_page ]
  end

  def self.kind_name kind
    @@KIND_NAMES ||= { :recipe_page => "Page of recipes" }
    @@KIND_NAMES[kind.to_sym] || kind.to_s.gsub('_',' ').capitalize
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
  # For modifying site parsing info (grammar, trimmers, etc.)
  accepts_nested_attributes_for :site

  has_many :referments, :as => :referee, :dependent => :destroy
  has_many :referents, :through => :referments, inverse_of: :page_refs

  before_save do |pr|
    alias_for(pr.url, true) if pr.url_changed? # Ensure that a page_ref's url is an alias, too
  end

  after_create { |pr| pr.request_attributes :url } # Need to launch after creation because, somehow, a new url doesn't count as changed

  after_save { |pr| pr.bkg_launch if pr.needed_attributes.present? } # ...because no launching occurred before saving

  # All other PageRefables refer to a separate PageRef, but we're our own page_ref
  def page_ref
    self
  end

  ######### Trackable overrides ############
  ############## Trackable ############
  # In the course of taking a request for newly-needed attributes, fire
  # off dependencies from gleaning and mercury_result, IF we need them to do our work
  def request_dependencies 
    # attrib_needed! :content, true if recipe_page_needed?
    from_gleaning = Gleaning.tracked_attributes & needed_attributes
    if either = from_gleaning.present?
      build_gleaning if !gleaning
      gleaning.request_attributes *from_gleaning
    end
    from_mercury = MercuryResult.tracked_attributes & needed_attributes
    if from_mercury.present?
      # Translate from our needed attributes to those provided by mercury_result
      build_mercury_result if !mercury_result
      mercury_result.request_attributes *from_mercury
      either = true
    end
    # We need to get attributes from Gleaning and/or Mercury
    either
  end

  # Ask gleaning and mercury_result for attributes
  def adopt_dependencies
    super if defined? super
    if gleaning.good?
      assign_attributes gleaning.ready_attribute_values.slice(*open_attributes)
    end
    # Note that if we got an attribute from the Gleaning, we no longer need it from MercuryResult
    if mercury_result.good? # All is well
      assign_attributes mercury_result.ready_attribute_values.slice(*open_attributes)
      if mercury_result.new_aliases_ready? && mercury_result.new_aliases.present?
        new_aliases = mercury_result.new_aliases.collect { |url| Alias.indexing_url url }
        # Create a new alias on this page_ref for every derived alias that isn't already in use
        (new_aliases - aliases.pluck(:url)).each { |new_alias| alias_for new_alias, true }
      end
    end
    if recipe_page_needed?
      recipe_page || build_recipe_page
      self.recipe_page = recipe_page
      # Could do this to get the RecipePage parsing done sooner
      # recipe_page.request_attributes :content
    end
  end

  ############ Backgroundable ###############
  # We attempt to drive MercuryResult and Gleaning to completion, then adopt the URLs derived therefrom,
  # in the expectation that other attributes will be extracted from the two separately.
  def perform
    if url_needed?
      # We need to follow any redirects from the current url.
      # The final (non-redirected) location will become our URL, and any
      # URLs that redirected along the way (including the first) become our aliases
      # NB Only the original URL is guaranteed not to be redundant, either in another page_ref
      # or an alias. If it's the latter, we capture the alias. If we can't adopt the URL without
      # clashing with another page_ref, we assign it to MercuryResult and Gleaning and give up.
      # Check the header for the url from the server.
      # If it's a string, the header returned a redirect
      # otherwise, it's an HTTP code
      logger.debug "Checking direct access of PageRef ##{id} at '#{url}'"
      subject_url = url
      # Loop over the redirects from the link, adding each to the record.
      # Stop when we get to the final page or an error occurs
      while (hr = header_result(subject_url)).is_a?(String)  # ...because redirect
        # header_result returns a string for a redirect
        next_url = hr.match(/^http/) ? hr : safe_uri_join(subject_url, hr).to_s # The redirect URL may only be a path
        if !Alias.urleq(subject_url, next_url) && alias_for?(next_url) # Time to give up when the url has been tried (it already appears among the aliases)
          # Report the error arising from direct access
          hr = header_result next_url
          break
        end
        logger.debug "Redirecting from #{subject_url} to #{next_url}"
        alias_for subject_url, true
        subject_url = next_url
      end
      self.url = subject_url
      hr # Return the last error code
    end

    # Now that we have a url, move on to the mercury_result and the gleaning
    mercury_result.ensure_attributes # Block until mercury_result has completed and accepted its attributes
    if mercury_result.bad?
      errors.add :url, "can\'t be accessed by Mercury: #{mercury_result.errors[:base]}"
    end
    self.http_status = mercury_result.http_status

    gleaning.ensure_attributes # Block until gleaning has completed and accepted its attributes
    if gleaning.bad?
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
    aliases.find { |al| al.url == iu } ||
        (assert &&
            aliases.build(url: iu)
        )
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
  #   whether an existing page_ref, or a newly-built one. Its URL will be in the
  #   canonical form (eliding the target)
  # String, PageRef => PageRef; nil => nil
  # Return a (possibly newly-created) PageRef on the given URL
  # NB Since the derived canonical URL may differ from the given url,
  # the returned record may not have the same url as the request
  def self.fetch url_or_page_ref, initializers={}
    # Enabling "fetch" of existing page_ref
    return url_or_page_ref if url_or_page_ref.is_a?(PageRef)
    # (self.find_by_url(url_or_page_ref) || self.build_by_url(url_or_page_ref)) if url_or_page_ref.present?
    if url_or_page_ref.present?
      standardized_url = PageRef.standardized_url url_or_page_ref
      unless pr = self.find_by_url(standardized_url)
        pr = self.new initializers.merge(url: standardized_url)
        yield pr if block_given?
        pr.request_attributes :url, force: true  # Redo to finalize url
      end
    end
    pr
  end

  def self.standardized_url url
    url.sub /\#[^#]*$/, '' # Elide the fragment for purposes of storage
  end

  # Assigning a new url has several side effects:
  # * initializing or finding the corresponding site
  # * clearing http_status and virginizing the PageRef in anticipation of launching it (when/if saved)
  # * ensuring the existence of virginized MercuryResult and Gleaning associates
  def url= new_url
    self.url_ready = true
    self.url_needed = false
    new_url = self.class.standardized_url new_url
    return if new_url == url
    super new_url # Heading for trouble if url wasn't unique
    @indexing_url = nil # Clear the memoized indexing_url
    self.http_status = nil # Reset the http_status
    # We do NOT build the associated site here, because we may be BUILDING the page_ref for a site, in
    # which case that site will assign itself to us. Instead, the site attribute is memoized, and if it
    # hasn't been built by the time that it is accessed, THEN we find or build an appropriate site
    self.site = SiteServices.find_or_build_for self
    self.kind = :site if site&.page_ref == self # Site may have failed to build
    # We trigger the site-adoption process if the existing site doesn't serve the new url
    # self.site = nil if site&.persisted? && (SiteServices.find_for(url) != site) # Gonna have to find another site
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

  private


  end
