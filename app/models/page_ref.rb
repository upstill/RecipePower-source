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
  has_one :recipe_page, :dependent => :destroy, :autosave => false

  # We track attributes from Gleanings and MercuryResult except URL
  include Trackable
  attr_trackable :url, :domain, :title, :content, :picurl, :date_published, :author, :description, :rss_feeds,
                 :recipe_page, :new_aliases, :http_status, :site

  # The associated Gleaning keeps the PageRef's content by default, with backup by MercuryResults
  def content
    return gleaning.content if gleaning&.content_ready?
  end

  def content= val
    gleaning.content = val # gleaning&.accept_attribute :content, val
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

=begin
  after_initialize do |pr|
    # The actual launch will occur once the url and http_status have settled
    request_attributes [ :picurl, :title ] unless persisted?
  end
=end

  before_save do |pr|
    alias_for(pr.url, true) if pr.url_changed? # Ensure that a page_ref's url is an alias, too
  end

  # All other PageRefables refer to a separate PageRef, but we're our own page_ref
  def page_ref
    self
  end

  ######### Trackable overrides ############
  ############## Trackable ############

  def standard_attributes
    [ :picurl, :title ]
  end

  # In the course of taking a request for newly-needed attributes, fire
  # off dependencies from gleaning and mercury_result, IF we need them to do our work
  def drive_dependencies minimal_attributes=needed_attributes, overwrite: false, restart: false
    return true if http_status_needed
    adopt_dependencies # Try to get attribs from gleaning and mercury as they stand
    # Filter the minimal attributes for those which are actually still needed
    minimal_attributes = attribs_needed! minimal_attributes, overwrite: overwrite
    if (nfg = needed_from_gleaning & minimal_attributes).present? && (!gleaning&.bad? || restart)
      ensure_gleaning.request_attributes nfg, overwrite: overwrite, restart: restart
    end
    if (nfm = needed_from_mercury & minimal_attributes).present? && (!mercury_result&.bad? || restart)
      ensure_mercury_result.request_attributes nfm, overwrite: overwrite, restart: restart
    end
    adopt_dependencies if nfm.present? || nfg.present? # Maybe attributes appeared during creation?
    # We need to get attributes from Gleaning and/or Mercury
    save if changed? && persisted? # Save later
    launch_on_save?
  end

  # Ask gleaning and mercury_result for attributes.
  # We assume that both have been settled in the course of #perform
  def adopt_dependencies synchronous: false, final: false
    if gleaning
      assign_from gleaning
      # Force the gleaning to completion of its background work
      gleaning.bkg_land! true if synchronous && !gleaning.complete? # needed_attributes.present?
      assign_from gleaning
    end
    # Note that if we got an attribute from the Gleaning, we no longer need it from MercuryResult
    if mercury_result
      assign_from mercury_result
      # Force the mercury_result to completion of its background work
      mercury_result.bkg_land! true if synchronous && !mercury_result.complete? # needed_attributes.present?
      assign_from mercury_result
    end
    if recipe_page_needed? # Should come to life with :content expected
      attrib_needed! :recipe_page, false
      self.recipe_page ||= build_recipe_page
    end
    if final
      self.content_needed = false # If after all this, we don't have content, that's okay (no error generated)
=begin
      if url_changed? && ![ gleaning&.url, mercury_result&.url ].compact.include?(new_url)
        refresh_attributes [ :picurl, :title ], restart: true
      end
=end
      # Report any errors from MercuryResult or Gleaning
      if gleaning&.complete? && (gleaning.http_status != 200)
        errors.add :url, "can\'t be gleaned: #{gleaning.errors[:base]}\n"
        self.url_needed = false
      end
      if mercury_result&.complete? && (mercury_result.http_status != 200)
        errors.add :url, "can\'t be accessed by Mercury: #{mercury_result.errors[:base]}"
        self.url_needed = false
      end
    end
    super if defined? super
  end

  ############ Backgroundable ###############
  # We attempt to drive MercuryResult and Gleaning to completion, then adopt the URLs derived therefrom,
  # in the expectation that other attributes will be extracted from the two separately.
  def perform
    probe_url if http_status_needed?

    # Now that we have a url and http_status, move on to the mercury_result and the gleaning

    # If MercuryResult or Gleaning have failed,
    # AND we want to give them another chance to complete,
    # AND we're dependent on values from them, then we throw an error to relaunch

    # Block (go back into the queue) until mercury_result has completed and accepted its attributes
    await ensure_mercury_result if needed_from_mercury.present?

    # Block (go back into the queue) until gleaning has completed and accepted its attributes
    await ensure_gleaning if needed_from_gleaning.present?

    # There's no more work to be done, aside from harvesting attributes from mr and gl

  end

  # We reschedule for AFTER the completion of jobs (Gleaning or MercuryResult) that we depend on
  def reschedule_at current_time, attempts
    reschedule_after mercury_result, gleaning { |delayed|
      super
    }
  end

  def after job=nil
    self.error_message = errors[:base].join "\n" # Persist the errors before (possibly) saving the record
    super
  end

  # We relaunch the job on errors, unless there's a permanent HTTP error
  def launch_on_save?
    # (Re)launch if there's anything to be gotten from mercury or gleaning
    (needed_from_mercury.present? && !mercury_result&.complete?) ||
        (needed_from_gleaning.present? && !gleaning&.complete?)
  end

  def relaunch_on_error?
    http_status_needed || !permanent_http_error?(http_status)
  end

  # Will this page_ref be found when looking for a page_ref of the given url?
  # (unlike #alias_for, it checks the url for a match before hitting the aliases)
  def answers_to? qurl
    Alias.urleq(qurl, url) || alias_for?(qurl)
  end

  # Find the alias associated with the given url, optionally building one
  def alias_for url, assert=false
    iu = Alias.indexing_url(url)
    aliases.to_a.find { |al| al.url == iu } ||
        (aliases.build url: iu if assert)
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

  # new_aliases is a virtual attribute for taking aliases from MercuryResult
  def new_aliases=urls
    urls.each { |new_alias| alias_for new_alias, true }
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
        initializers = initializers[:http_status] ?
                           initializers.merge(url_and_status: [ standardized_url, initializers[:http_status] ]) :
                           initializers.merge(url: standardized_url)
        pr = self.new initializers
        # We didn't find an existing page_ref by the given url, but that doesn't mean
        # that there isn't one that it redirects to.
        # HOWEVER, the candidate will return from assigning the url with a redirect chain
        pr.aliases.to_a.each { |a| }
        yield pr if block_given?
      end
    end
    pr
  end

  def self.standardized_url url
    url.sub /\#[^#]*$/, '' # Elide the fragment for purposes of storage
  end

  # A version of url= which takes a new url to assign and returns the PageRef which
  # uniquely represents that url. This is generally the PageRef receiving it, but
  # in the case where the new url is already represented by a different PageRef,
  # that's the one that gets returned. This is how we maintain uniqueness of urls
  # while enabling them to be reassigned. NB: no conventional url= call will provide
  # this insurance. (Pagerefable does, in taking urls for assignment)
  def safe_assign new_url
    self.url_ready = true
    self.url_needed = false
    return self unless acceptable_url?(new_url) { |err| errors.add :url, err }
    write_attribute :url, self.class.standardized_url(new_url) # Heading for trouble if url wasn't unique

    # Ensure there's an alias
    alias_for new_url, true

    # Creating or otherwise building the page ref: Quickly assess the http_status
    # We refresh the http_status without consulting mercury_result or gleaning
    # When a new url is asserted, we will have to get its http_status UNLESS it's already among our aliases
    # We'll also have to consult MercuryResult and Gleaning, so just destroy them now
    gleaning&.destroy ; self.gleaning = nil
    mercury_result&.destroy ; self.mercury_result = nil
    errors.delete :url # Clear pending probe
    alt = probe_url
    # If probing the url turns up an alias or a redirect that leads to a different PageRef, we return that without further ado
    if alt != self
      return alt
    elsif errors[:url].any?  # url was (ultimately) good
      self.status = :bad
      self.error_message = errors.full_messages_for :url
    else
      refresh_attributes [ :picurl, :title ], restart: true unless [ gleaning&.url, mercury_result&.url ].compact.include?(new_url)
    end
    # We do NOT build the associated site here, because we may be BUILDING the page_ref for a site, in
    # which case that site will assign itself to us. Instead, the site attribute is memoized, and if it
    # hasn't been built by the time that it is accessed, THEN we find or build an appropriate site
    # self.site = SiteServices.find_or_build_for self
    # self.kind = :site if site&.page_ref == self # Site may have failed to build
    # We trigger the site-adoption process if the existing site doesn't serve the new url
    # self.site = nil if site&.persisted? && (SiteServices.find_for(url) != site) # Gonna have to find another site
    return self
  end

  # Assigning a new url has several side effects:
  # * initializing or finding the corresponding site
  # * clearing http_status and virginizing the PageRef in anticipation of launching it (when/if saved)
  # * ensuring the existence of virginized MercuryResult and Gleaning associates
  def url= new_url
    safe_assign new_url # Sadly, all we do to protect against a non-unique new_url is post an error
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

  # This virtual attribute allows the url and the confirming http_status to be set at once,
  # eliding the accessibility check that comes from url=
  def url_and_status= associate_or_twofer
    # Get url and http_status either via an associate, or directly from a two-element array
    twofer =
        case associate_or_twofer
        when Array
          associate_or_twofer
        else
          [associate_or_twofer.url, associate_or_twofer.http_status]
        end
    # The parameter is a url/status pair
    return unless twofer.first.present? # We don't accept nil urls
    new_url, self.http_status = self.class.standardized_url(twofer.first), twofer.last
    self.url_ready = true
    self.url_needed = false
    return if (old_url = url) == new_url # No need to proceed further if the url isn't changing
    # Viable url to be gotten from element => get url and http_status together, without checking for accessibility or other side effects
    write_attribute :url, new_url
    alias_for url, true # Ensure the presence of an alias
    if http_status == 200 # If status is okay, start building the site
      self.site = SiteServices.find_or_build_for self
      self.kind = :site if site&.page_ref == self # Site may have failed to build
      # When getting the url and status from gleaning or mercury_result, we assume that others will launch for attributes as needed
      refresh_attributes([:picurl, :title], restart: true) if associate_or_twofer.is_a?(Array)
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

  private

  # Test the url attribute for accessibility,
  # -- follow any redirects
  # -- set http_status to the header status of the last redirect
  # -- if the last redirect fails, invoke mercury_result and gleaning to see if they do any better
  # -- revise the url attribute as needed
  def probe_url
    # We need to follow any redirects from the current url.
    # The final (non-redirected) location will become our URL, and any
    # URLs that redirected along the way (including the first) become our aliases
    # NB Only the original URL is guaranteed not to be redundant, either in another page_ref
    # or an alias. If it's the latter, we capture the alias. If we can't adopt the URL without
    # clashing with another page_ref, we assign it to MercuryResult and Gleaning and give up.
    old_url = url
    rds = redirects url
    self.http_status = rds.pop
    self.new_aliases = rds # Add new aliases as needed
    new_url = PageRef.standardized_url(rds.pop)
    if (url != new_url) &&
        (extant = PageRef.find_by_url(new_url)) &&
        (extant != self) # Proposed new URL clashes with existing
      # Non-unique URL bad!
      puts "URL '#{new_url}' already in use!" if Rails.env.test?
      self.errors.add :url, "'#{url}' was redirected to '#{new_url}', which is already taken."
      return extant
    end
    if http_status == 200 # Hitting the URL succeeded
      write_attribute :url, new_url
    else # Bad URL: see if mercury and/or gleaning can do any better
      # Hopefully we'll pick up a valid URL from one of them
      ensure_gleaning.ensure_attributes [ :http_status ], overwrite: true, restart: true
      ensure_mercury_result.ensure_attributes [ :http_status ], overwrite: true, restart: true
      self.url_needed = self.http_status_needed = true
      adopt_dependencies final: true
      self.url_needed = self.http_status_needed = false # Close url and status even if not acquired from associate
    end
    if http_status == 200
      self.site = SiteServices.find_or_build_for self
      self.kind = :site if site&.page_ref == self # Site may have failed to build
    end
    if Rails.env.test?
      puts "Replaced url '#{old_url}'"
      puts "URL '#{new_url}' yields http_status #{http_status}\n\tAliases:"
      aliases.to_a.map(&:url).each { |u| puts "\t#{u}" }
    end
    return self
  end

  def ensure_mercury_result
    mercury_result || (self.mercury_result = build_mercury_result)
  end

  def ensure_gleaning
    gleaning || (self.gleaning = build_gleaning)
  end

  def needed_from_mercury
    MercuryResult.tracked_attributes & needed_attributes
  end

  def needed_from_gleaning
    Gleaning.tracked_attributes & needed_attributes
  end

  def assign_from associate
    to_assign = open_attributes
    # Assign the url only if the entity's derived http_status is appropriate
    self.url_and_status = associate if !associate.http_status_needed && associate.http_status == 200 # [400,  401, 403, 404, 414, 500 ].include?(associate.http_status)
    to_assign = to_assign - [ :url, :http_status ] # Regardless, we don't do mass assignment of url and status
    assign_attributes associate.ready_attribute_values.slice(*to_assign)
  end

end
