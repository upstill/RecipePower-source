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

  serialize :mercury_results, Hash

  # Specify what values from the gleaning correspond to one of our attributes
  @@gleaning_correspondents = {
      # domain: nil,
      'url' => 'URI',
      'title' => 'title',
      'description' => 'description',
      # date_published => nil,
      'author' => 'author',
      'content' => 'content',
      'picurl' => 'image'
  }
  # Specify what values from mercury_results correspond to one of our attributes
  @@mercury_correspondents = {
      'url' => 'url',
      'domain' => 'domain',
      'title' => 'title',
      'description' => 'description',
      'date_published' => 'date_published',
      'author' => 'author',
      'content' => 'content',
      'picurl' => 'lead_image_url'
  }
  @@extractable_attributes = @@gleaning_correspondents.keys | @@mercury_correspondents.keys
  
  @@extractions_correspondents = {
      'url' => "URI",
      'picurl' => "Image",
      'title' => "Title",
      # "Author Name",
      # "Author Link",
      'description' => "Description",
      # "Tags",
      # "Site Name",
      # "RSS Feed",
      'author' => "Author",
      'content' => "Content"
  }

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
    belongs_to :gleaning
  else
    belongs_to :gleaning, optional: true
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
    kind.is_a?(Fixnum) ? where(kind: kind) : where(kind: PageRef.kinds[kind])
  }

  has_many :recipes, :dependent => :nullify # , foreign_key: 'page_ref_id'
  has_many :sites, :dependent => :nullify # , foreign_key: 'page_ref_id'

  # belongs_to :site, foreign_key: 'affiliate_id'
  # before_save :fix_host

  # alias_method :host, :domain
  def host
    domain
  end

  # The site for a page_ref is the Site object with the longest root matching the canonical URL
  belongs_to :site

  has_many :referments, :as => :referee, :dependent => :destroy
  has_many :referents, :through => :referments, inverse_of: :page_refs

=begin
  before_save do |pr|
    if (!pr.site?) && (pr.url_changed? || !pr.site) && pr.url.present?
      puts "Find/Creating Site for PageRef ##{pr.id} w. url '#{pr.url}'"
      pr.site = Site.find_or_create_for(pr)
    end
  end
=end

  before_save do |pr|
    alias_for pr.url, true # Ensure there's an alias which will find this page_ref
  end

  after_create { |pr| pr.bkg_launch }

  after_save do |pr|
    if pr.url.present? && !(pr.site_id || pr.site)
      puts "Find/Creating Site for PageRef ##{pr.id} w. url '#{pr.url}'"
      unless pr.site = Site.find_by(page_ref_id: id)
        pr.site = Site.find_or_create_for pr.url
        pr.site.page_refs << self
        pr.update_attribute :site_id, pr.site.id
      end
    end
  end

  def page_ref
    self
  end

  # Glean info from the page in background as a DelayedJob job
  # force => do the job even if it was priorly complete
  def bkg_launch force=false
    super do
      self.gleaning ||= create_gleaning # if needs_gleaning?
    end
  end
  
  # We get potential attribute values (as needed) from Mercury, and from gleaning the page directly
  def perform
    if open_attributes.present?
      get_mercury_results if mercury_results.blank? || (http_status != 200)
      adopt_mercury_results # Should this depend on http_status? Should it report an error?

      self.gleaning ||= create_gleaning page_ref: self
      gleaning.bkg_land # Ensure the gleaning has happened
      errors.add(:url, 'can\'t be gleaned') if gleaning.bad?
      adopt_gleaning_results if gleaning.good?

    end
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
    aliases.map(&:url).include?(Alias.indexing_url iu)
  end

  def elide_alias url
    if al = alias_for(url)
      aliases.delete al
    end
    url
  end

  # Consult Mercury on a url and report the results in the model
  # status: :good iff Mercury could get through to the resource, :bad otherwise
  # http_status: 200 if Mercury could get through to the resource OR the HTTP code (from the header) for a direct fetch
  # errors: set a URL error iff the URL can't be parsed by URI, in which case the PageRef shouldn't be saved and will
  #     likely throw a validation error
  # Note that even if Mercury can crack the page, that's no guarantee that any metadata except the URL and domain are valid
  # The purpose of status is to indicate whether Mercury might be tried again later (:bad)
  # The purpose of http_status is a positive indication that the page can be reached
  # The purpose of errors are to show that the URL is ill-formed and the record should not (probably cannot) be saved.
  def get_mercury_results
    self.extant_pr = nil # This identifies (unpersistently) a PageRef which clashes with a derived URL
    new_aliases = [] # We accumulate URLs that got redirected on the way from the nominal URL to 
    begin
      mercury_data = try_mercury url
      if mercury_data['domain'] == 'www.answers.com'
        # We can't trust answers.com to provide a straight url, so we have to special-case it
        mercury_data['url'] = url
      end
      self.http_status =
          if mercury_data['mercury_error'].blank? # All good from Mercury
            200
          else
            # Check the header for the url from the server.
            # If it's a string, the header returned a redirect
            # otherwise, it's an HTTP code
            puts "Checking direct access of PageRef ##{id} at '#{url}'"
            redirected_from = nil
            # Loop over the redirects from the link, adding each to the record.
            # Stop when we get to the final page or an error occurs
            while hr = header_result(mercury_data['url'])
              # header_result returns either
              # an integer result code (final result), or
              # a string url for redirection
              if hr.is_a?(Fixnum)
                if (hr == 404) && redirected_from
                  # Got a redirect via Mercury, but the target failed
                  mercury_data['url'] = new_aliases.delete redirected_from
                  # mercury_data['url'] = elide_alias redirected_from
                  hr = 303
                end
                break;
              end
              hr = safe_uri_join(mercury_data['url'], hr).to_s unless hr.match(/^http/) # The redirect URL may only be a path
              break if alias_for hr # Time to give up when the url has been tried (it already appears among the aliases)
              puts "Redirecting from #{mercury_data['url']} to #{hr}"
              begin
                new_aliases << (redirected_from = mercury_data['url'])
                # alias_for((redirected_from = mercury_data['url']), true) # Stash the redirection source in the aliases
                # self.aliases |= [redirected_from = mercury_data['url']]
                mercury_data = try_mercury hr
                if (self.error_message = mercury_data['mercury_error']).blank? # Success on redirect
                  hr = 200
                  break;
                end
              rescue Exception => e
                # Bad URL => Remove the last alias
                mercury_data['url'] = new_aliases.delete if redirected_from
                # mercury_data['url'] = elide_alias(redirected_from) if redirected_from
                hr = 400
              end
            end
            hr.is_a?(String) ? 666 : hr
          end
      if http_status != 200
        errors.add(:url, 'is inaccessible to Mercury')
      end
      mercury_data['content'] = mercury_data['content']&.tr "\x00", ' ' # Mercury can return strings with null bytes for some reason
      self.mercury_results = mercury_data
      mercury_results['new_aliases'] = new_aliases
    rescue Exception => e
      self.error_message = "Bad URL '#{url}': #{e}"
      self.http_status = 400
    end
  end

  def try_mercury url
    previous_probe = nil
    api = 'http://173.255.255.234:8888/myapp?url='
    current_probe = api + url
    data = response = nil
    while(previous_probe != current_probe) do
      uri = URI.parse current_probe
      previous_probe = current_probe
      http = Net::HTTP.new uri.host, uri.port
      # http.use_ssl = true

      req = Net::HTTP::Get.new uri.to_s
      req['x-api-key'] = ENV['MERCURY_API_KEY']

      response = http.request req
      data =
          case response.code
          when '401'
            ActiveSupport::HashWithIndifferentAccess.new(url: url, content: '', errorMessage: '401 Unauthorized')
          when '301' # "Permanently Moved"
            current_probe = response.body.split[2]
            current_probe.sub! /^\//, api
            ActiveSupport::HashWithIndifferentAccess.new
          else
            JSON.parse(response.body) rescue ActiveSupport::HashWithIndifferentAccess.new(url: url, content: '', errorMessage: 'Empty Page')
          end
    end

    # Do QA on the reported URL
    # Report a URL as extracted by Mercury (if any), or the original URL (if not)
    uri = data['url'].present? ? safe_uri_join(url, data['url']) : URI.parse(url) # URL may be relative, in which case parse in light of provided URL
    data['url'] = uri.to_s
    data['domain'] ||= uri.host
    data['response_code'] = response.code
    # Merge different error states into a mercury_error
    data['mercury_error'] = data['errorMessage'].if_present || (data['message'] if data['error'])
    data.delete :errorMessage
    data.delete :error
    data
  end

  def table
    self.arel_table
  end

  # Lookup a PageRef by resort to the Alias table
  def self.find_by_url url
    # self.joins(:aliases).find_by Alias.url_query(url)
    Alias.includes(:page_ref).find_by_url(url)&.page_ref
  end

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

  def url= new_url
    @indexing_url = nil # Clear the memoized indexing_url
    super self.class.standardized_url(new_url) # Heading for trouble if url wasn't unique
  end

  # Before assigning a url and possibly triggering an error, check to see how it will play out
  # If provided with a block, call it with an appropriate error message
  # There are three checks here:
  # 1) check that it's a well-formed URL
  # 2) that it actually changes the url attribute
  # 3) that one of the existing aliases covers it (so it won't generate a non-unique alias)
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
      yield 'is already in use elsewhere.' if block_given?
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

  # Enumerate the attributes that remain open
  def open_attributes
    @@extractable_attributes.select { |attrname| self.send(attrname).blank? }
  end

  # Once Mercury and gleaning has happened, reconcile our attributes with values from them
  def adopt_extractions extraction_params
    @extractions = extraction_params
    # Extractions are only provided in the context of the injector, by analysis of the page in situ
    # Since THAT only occurs when an entity is first captured, we let the extracted title prevail
    open_attributes+['title'].each { |name| adopt_extraction_value_for name }
  end

  # Get a value from the gleaning for our attribute of the given name.
  # This is necessary because the same value isn't necessarily named the same in the two
  def adopt_extraction_value_for name
    # The conditional protects against asking the gleaning for an unknown value
    if (extraction_val = @extractions[@@extractions_correspondents[name]]).present?
      self.send name+'=', extraction_val unless name == 'url' && !acceptable_url?(extraction_val)
    end
  end

  def adopt_gleaning_results
    open_attributes.each { |name| adopt_gleaning_value_for name } if gleaning&.good?
  end

  # Get a value from the gleaning for our attribute of the given name.
  # This is necessary because the same value isn't necessarily named the same in the two
  def adopt_gleaning_value_for name
    # The conditional protects against asking the gleaning for an unknown value
    return unless @@gleaning_correspondents[name].present? &&
        (gleaning_val = gleaning&.send(@@gleaning_correspondents[name])).present?
    self.send name+'=', gleaning_val unless name == 'url' && !acceptable_url?(gleaning_val)
  end

  def adopt_mercury_results
    # Mercury leaves an array of redirected URLs found on the way to the final url
    # Assign those that aren't already assigned to this page_ref
    if (reduced_aliases = mercury_data['new_aliases']&.collect { |url| Alias.indexing_url url }).present?
      (reduced_aliases - Alias.where(url: reduced_aliases).pluck( :url)).
      each { |new_alias| alias_for new_alias, true }
    end

    # Address Mercury data. The key issue is whether Mercury redirected to a url that is
    # 1) different than the current one
    # 2) already held by another page_ref.
    # Since urls must be unique, this is an error requiring the two page_refs to be merged.
    open_attributes.each { |name| adopt_mercury_value_for name } if mercury_results.present?
  end

  def adopt_mercury_value_for name
    # The conditional protects against asking the mercury_results for an unknown value
    return unless (mercury_val = mercury_results[@@mercury_correspondents[name]]).present?
    self.send name+'=', mercury_val unless name == 'url' && !acceptable_url?(mercury_val)
  end

  private

=begin

  def url= url
    super
  end
=end

end
