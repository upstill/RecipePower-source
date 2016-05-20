require 'RMagick' unless Rails.env.development?
require 'open-uri'
require 'mechanize'
require 'fileutils'

class Reference < ActiveRecord::Base

  include Referrable
  include Typeable

  attr_accessible :reference_type, :type, :url, :affiliate_id, :filename

  validates_uniqueness_of :url, :scope => :type

  typeable( :reference_type,
    Article: ['Article', 1],
    Newsitem: ['News Item', 2],
    Tip: ['Tip', 4],
    Video: ['Video', 8],
    Definition: ['Glossary Entry', 16],
    Homepage: ['Home Page', 32],
    Product: ['Product', 64],
    Offering: ['Offering', 128],
    Recipe: ['Recipe', 256],
    Image: ['Image', 512],
    Site: ['Site', 1024],
    Event: ['Event', 2048]
  )

  public

  # By default, the reference gives up its url, but may want to use something else, like image data
  def digested_reference
    url
  end

  # Convert back and forth between class and typenum (for heeding type selections)
  def self.type_to_class typenum=0
    return Reference if !typenum || typenum == 0
    ((self.typesym(typenum) || "").to_s+"Reference").constantize
  end

  def typesym
    self.class.to_s.sub( 'Reference', '' ).to_sym
  end

  def typenum
    return 0 if self.class == Reference
    Reference.typenum typesym
  end

  # Use a normalized URL to find a matching reference of the given type.
  # The 'partial' flag indicates that it's sufficient for the URL to match a substring of the target record
  def self.lookup_by_url type, normalized_url, partial=false
    typescope = Reference.where type: type
    sans_protocol = normalized_url.sub /^(http[^\/]*)?\/\//, '' # Remove the protocol from consideration
    if partial
      typescope.where 'url ILIKE ?', '%://' + sans_protocol + '%'
      # Reference.where "type = '#{type}' and url ILIKE ?", normalized_url+"%"
    else
      typescope.where url: ['http://'+sans_protocol, 'https://'+sans_protocol]
      # Reference.where type: type, url: normalized_url
    end
  end

  # Index a Reference by URL or URLs, assuming it exists (i.e., no initialization or creation)
  def self.lookup url_or_urls, partial=false
    if self.affiliate_class
      (url_or_urls.is_a?(Array) ? url_or_urls : [url_or_urls]).map { |url|
        normalize_url url
      }.keep_if { |normalized_url|
        normalized_url.present?
      }.uniq.collect { |normalized_url|
        Reference.lookup_by_url(self.to_s, normalized_url, partial).to_a
      }.flatten.compact.uniq
    end
  end

  # Lookup the affiliate(s) that match the given url(s).
  # 'by_site' stipulates that an initial substring match suffices
  def self.lookup_affiliates url_or_urls, partial=false
    if self.affiliate_class # Referents need not apply (unknown affiliate class)
      unless (ids = self.lookup(url_or_urls, partial).map(&:affiliate_id).compact.uniq).empty?
        return self.affiliate_class.find ids
      end
    end
    []
  end

  def self.lookup_affiliate url_or_urls, partial=false
    if self.affiliate_class # Referents need not apply (unknown affiliate class)
      unless (ids = self.lookup(url_or_urls, partial).map(&:affiliate_id).compact.uniq).empty?
        self.affiliate_class.find ids.first
      end
    end
  end

  # Provide a relation for entities that match a string
  def self.strscopes matcher
    [
        (block_given? ? yield() : self).where('"references"."host" ILIKE ?', matcher)
    ]
  end

  # Return a (perhaps unsaved) reference for the given url
  # params containts attribute name-value pairs for initializing the reference
  # AND ALSO an :affiliate, the object the reference is about (e.g., Site, Recipe...)
  def self.find_or_initialize url, params = {}

    # URL may be passed as a parameter or in the params hash
    if url.is_a? Hash
      params = url
      url = params[:url]
    else
      params[:url] = url
    end
    # IMPORTANT! the type of reference is determined from the invoked class if not given specifically
    if url.match(/^data:/)
      return [ self.create_with(url: url, canonical: true).find_or_create_by( type: 'ImageReference', thumbdata: url) ]
    end
    params[:type] ||= self.to_s

    # Normalize the url for lookup
    normalized = normalize_url url
    if normalized.blank? # Check for non-empty URL
      ref = self.new params # Initialize a record just to report the error
      ref.errors.add :url, "can't be blank"
      refs = [ref]
    else
      refs = self.lookup_by_url(params[:type], normalized).order 'canonical DESC'
      if refs.empty?
        # Need to create, if possible
        if !(redirected = test_url normalized) # Purports to be a url, but doesn't work
          refs = [self.new(params)] # Initialize a record just to report the error
          refs.first.errors.add :url, "\'#{url}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
        else
          # No reference to be found under the given (normalized) URL -> create one, and possibly its canonical reference as well
          # The goal is to ensure access through any given link that resolves to the same URL after normalization and any redirection.
          # We achieve this by creating references, each pointing to the same affiliate, on at most two URLS:
          #  1) the original URL (after normalization), so identical references wind up with the identical affiliate; and
          #  2) the URL as redirected by the site in question (and again normalized), so that future URLS that redirect
          #   to the same place get to the same affiliate.
          # NB: It's true that we could simply use the redirected URL for looking up a reference, but that would require
          #  hitting the site every time that URL was referenced. This way, we only have to take the redirection once, and
          #  the Reference class remembers the mapping.
          refs = Reference.lookup_by_url(params[:type], redirected).to_a
          # refs = Reference.where(type: params[:type], url: redirected).to_a
          refs = [ Reference.new(type: params[:type], url: redirected) ] if refs.empty?
          (canonical = refs.first).canonical = true # Make the redirected reference be canonical, and first
          # Now we create a new reference, aliased to that of the canonical reference by making their affiliate id's the same
          refs << Reference.new(type: params[:type], :url => normalized, affiliate_id: canonical.affiliate_id ) if normalized != redirected
        end
      end
    end
    refs
  end

  # Assert a reference to the given URL, linking back to a referent
  def self.assert(uri, tag_or_referent, type=:Definition )
    refs = "#{type}Reference".constantize.find_or_initialize uri
    refs.each { |me| me.assert tag_or_referent, type } if refs.first.errors.empty?
    refs.first
  end

  def assert tag_or_referent, type=:Definition
    rft =
        case tag_or_referent
          when Tag
            Referent.express tag_or_referent
          else
            tag_or_referent
        end
    if rft
      self.referents << rft unless referents.exists?(id: rft.id)
      save
    end
  end

  # Ping the reference's URL, setting its canonical bit appropriately
  def ping
    self.url = normalize_url(url) unless self.canonical # We keep the canonical url exactly as redirected (no normalization)
    if redirected = test_url(url)
      unless self.canonical = (redirected == url)
        # We need a separate canonical record
        can = self.dup
        can.canonical = true
        can.url = redirected
        can.save
      end
    end
    self.save
  end

  # Get data from the reference via HTTP
  def fetch
    def get_response url
      self.errcode = response = nil
      begin
        uri = URI.parse url
        if uri.host &&
            uri.port &&
            (http = Net::HTTP.new(uri.host, uri.port)) &&
            (uri.scheme != 'https' || (http.use_ssl = true && http.verify_mode = OpenSSL::SSL::VERIFY_NONE)) # read into this
            (request = Net::HTTP::Get.new(uri.request_uri, 'upgrade-insecure-requests' => '1'))
          response = http.request request
          self.errcode = response.code.to_i
        else # Invalid URL
          self.errcode = 400
        end
      rescue Exception => e
        # If the server doesn't want to talk, we assume that the URL is okay, at least
        case e
          when Errno::ECONNRESET
            self.errcode = 401
          else
            self.errcode = -1  # Undifferentiated error during fetch, possibly a parsing problem
        end
      end
      response
    end

    # get_response records the errcode of the last HTTP access in self.errcode
    tried = {}
    next_try = url
    until tried[next_try]
      tried[next_try] = true
      response = get_response next_try
      case errcode
        when 200
          return response.body
        when 301, 302 # Redirection
          next_try = response.header['location']
        when 401 # Unauthorized
          next_try.sub! /^https/, 'http'
      end
    end
  end

  # Give a reference an affiliate object (if any), raising an exception if one already exists, or types don't match
  def affiliate= affiliate
    if affiliate
      if affiliate.class != affiliate_class # self.class.to_s != "#{affiliate.class.to_s}Reference"
        raise "Attempt to affiliate #{self.class.to_s} reference with #{affiliate.class} object."
      elsif affiliate_id && (affiliate_id != affiliate.id)
        raise 'Attempt to create ambiguous reference by asserting new affiliate'
      else
        self.affiliate_id = affiliate.id
      end
    end
  end

  # Point the references affiliated with one entity to another, presumably b/c the old one is going away.
  # It is an error if they aren't of the same type
  def self.redirect old_affiliate, new_affiliate

  end

  protected

  # Extract the affiliated object, according to the type of reference
  def affiliate
    self.affiliate_class && affiliate_id && self.affiliate_class.find(affiliate_id)
  end

  # What's the class of the associated affiliate?
  def affiliate_class
    self.class.affiliate_class
  end

  # What's the class of the associated affiliate (subclasses of Reference only)
  def self.affiliate_class
    self.to_s.sub(/Reference$/, '').constantize unless (self == Reference)
  end

end

class ArticleReference < Reference

end

class NewsitemReference < Reference

end

class TipReference < Reference

end

class VideoReference < Reference

end

class DefinitionReference < Reference

end

class HomepageReference < Reference

end

class ProductReference < Reference

end

class OfferingReference < Reference

end

class RecipeReference < Reference
  belongs_to :recipe, foreign_key: 'affiliate_id'

  def self.lookup_recipe url_or_urls, by_site=false
    self.lookup_affiliate url_or_urls, by_site
  end

  def self.lookup_recipes url, by_site=false
    self.lookup_affiliates url, by_site
  end

  def self.scrape first=''
    mechanize = Mechanize.new

    mechanize.user_agent_alias = 'Mac Safari'

    chefs_url = 'http://www.bbc.co.uk/food/chefs'

    STDERR.puts "** Getting #{chefs_url}"
    chefs_page = mechanize.get(chefs_url)

    chefs_page.links_with(href: /\/by\/letters\//).each do |link|
      link_ref = link.to_s
      if link_ref.last.downcase >= first.first
        chefs = []
        STDERR.puts "-> Clicking #{link}"
        atoz_page = mechanize.click(link)
        atoz_page.links_with(href: /\A\/food\/chefs\/\w+\z/).each do |link|
          chef_id = link.href.split('/').last
          chefs << chef_id unless chef_id <= first
        end

        search_url = 'http://www.bbc.co.uk/food/recipes/search?chefs[]='

        chefs.each do |chef_id|
          results_pages = []

          STDERR.puts "** Getting #{search_url + chef_id}"
          results_pages << mechanize.get(search_url + chef_id)

          dirname = File.join('/var/www/RP/files/chefs', chef_id)

          FileUtils.mkdir_p(dirname)

          while results_page = results_pages.shift
            links = results_page.links_with(href: /\A\/food\/recipes\/\w+\z/)

            links.each do |link|
              path = File.join(dirname, File.basename(link.href) + '.html')

              STDERR.puts "+ #{link.href} => #{path}"

              url = normalize_url "http://www.bbc.co.uk#{link.href}"
              next if File.exist?(path) || Reference.lookup_by_url('RecipeReference', url).exists?

              # mechanize.download(link.href, path)
              RecipeReference.create url: url, filename: path
            end

            if next_link = results_page.links.detect { |link| link.rel?('next') }
              results_pages << mechanize.click(next_link)
            end
          end
        end
        chefs.last
      end
    end
  end
end

class ImageReference < Reference
  include Backgroundable

  backgroundable :status

=begin
  # This SHOULD be a better way to ensure that an ImageReference knows about all entities that could be pointing to it.
  # However, until we can ensure that all such entities are loaded before querying the relations, we'll have to live
  # with explicitly declaring the relations below
  def self.register_client klass, attribute_name
    unless (@@Clients ||= {})[klass]
      attribute_name = attribute_name.to_s + '_id'
      @@Clients[klass] = attribute_name
      assoc_sym = klass.to_s.underscore.pluralize.to_sym
      has_many assoc_sym, :foreign_key => attribute_name.to_sym
    end
  end
=end

  # An Image Reference maintains a local thumbnail of the image
  has_many :feeds, :foreign_key => :picture_id
  has_many :feed_entries, :foreign_key => :picture_id
  has_many :lists, :foreign_key => :picture_id
  has_many :products, :foreign_key => :picture_id
  has_many :recipes, :foreign_key => :picture_id
  has_many :sites, :foreign_key => :thumbnail_id
  has_many :users, :foreign_key => :thumbnail_id

  # Return the set of objects referring to this image
  def clients
    feeds.to_a +
        feed_entries.to_a +
        lists.to_a +
        products.to_a +
        recipes.to_a +
        sites.to_a +
        users.to_a
=begin
    @@Clients.collect { |klass, attribute|
      klass.where(attribute => id).to_a
    }.flatten
=end
  end

  def clients?
    !(feeds.empty? &&
        feed_entries.empty? &&
        lists.empty? &&
        products.empty? &&
        recipes.empty? &&
        sites.empty? &&
        users.empty?)
=begin
    @@Clients.each { |klass, attribute|
      puts "Testing for existence of #{klass} #{attribute}:"
      ct = klass.where(attribute => id).count
      puts  "#{ct} #{klass.to_s.pluralize}."
      x = ct > 0
      return true if x
    }
    false
  end
=end
  end

  def self.lookup_image url
    self.lookup_affiliate url
  end

  def self.lookup_images url, by_site=false
    self.lookup_affiliates url, by_site
  end

  # Since the URL is never written once established, this method uniquely handles both
  # data URLs (for images with data only and no URL) and fake URLS (which are left in place for the latter)
  # NB: Implicit in here is the strategy for maintainng the data: since we only fetch refrence
  # records by URL when assigning a URL to an entity, we only go off to update the data when
  # the URL is assigned
  def self.find_or_initialize url, params={}
    [
        case url
          when /^\d\d\d\d-/
            self.find_by url: url # Fake url previously defined
          when /^data:/
            self.find_by(thumbdata: url) || self.new(url: self.fake_url, thumbdata: url)
          when nil
          when ''
          else
            candidates = super # Find by the url
            # Queue the refs up to get data for the url as necessary and appropriate
            candidates.map &:launch
            # Check all the candidates for a data: URL, and return the canonical one or the first one, if none is canonical
            candidates.find &:canonical || candidates.first
        end
    ]
  end

  # Provide suitable content for an <img> element: preferably data, but possibly a url or even (if the data fetch fails) nil
  def imgdata force=false
    # Provide good thumbdata if possible
    bkg_sync(force) ? thumbdata : url
  end

  # Try to fetch thumbnail data for the record. Status code assigned in ImageReference#fetchable and Reference#fetch
  def perform
    logger.info ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> Acquiring Thumbnail data on url '#{url}' >>>>>>>>>>>>>>>>>>>>>>>>>"
    bkg_execute do
      # A url which is a date string denotes an ImageReference which came in as data, and is therefore good
      (url =~ /^\d\d\d\d-/) ||
      begin
        self.errcode = 0 if self.errcode == -2
        if response_body = fetch # Attempt to get data at the other end of the URL
          begin
            img = Magick::Image::from_blob(response_body).first
            if img.columns > 200
              scalefactor = 200.0/img.columns
              thumb = img.scale(scalefactor)
            else
              thumb = img
            end
            thumb.format = 'PNG'
            quality = 80
            self.thumbdata = 'data:image/png;base64,' + Base64.encode64(thumb.to_blob { self.quality = quality })
          rescue Exception => e
            logger.debug "Failed to parse image data for ImageReference#{id}: #{url} (#{e})"
            self.errcode = -2 # Bad data
          end
        end
        save # Save the errcode code, if nothing else
        errcode == 200 # Let bkg_execute know how we did
      end
    end
  end

  # Provide the phony (but unique) URL that's used for a data-only image
  def self.fake_url
    randstr = (0...8).map { (65 + rand(26)).chr }.join
    Time.new.to_s + randstr
  end

  # Ensure the thumbdata is up to date, optionally forcing an update even if previously processed
  def launch force=false
    if url =~ /^\d\d\d\d-/
      (good! && save) unless good?
    elsif url.blank?
      (bad! && save) unless bad?
    else
      bkg_enqueue force
    end
  end

  private

  def thumbdata
    self[:thumbdata]
  end

  def thumbdata=(val)
    write_attribute :thumbdata, val
  end

=begin
  # Return the URL if it passes a sanity check. NB: a url with a date denotes a record that's all imagedata
  def usable_url ignore_status=false
    unless url.blank? || (url =~ /^\d\d\d\d-/)
      if ignore_status
        url
      else
        fetch if !errcode # Not previously tested
        url if errcode==200
      end
    end
  end
=end

end

# Site references are indexed by the initial substring of a url
# (specifically, the protocol, domain and host, plus any path used to distinguish different sites with the same host).
class SiteReference < Reference
  belongs_to :site, foreign_key: "affiliate_id"
  before_save :fix_host

  # Return the definitive url for a given url. NB: This will only be the site portion of the URL
  def self.canonical_url url
    normalized_link = normalize_url(url).sub(/\/$/,'')
    if host_url = host_url(normalized_link)
      # Candidates are all sites with a matching host
      matches = Reference.lookup_by_url 'SiteReference', host_url, true
      # matches = Reference.where(type: "SiteReference").where('url ILIKE ?', "#{host_url}%")
      matches.map(&:url).inject(nil) { |result, this|
        # If more than one match, seek the longest
        result = this if normalized_link.start_with?(this) && (!result || (result.length < this.length))
        result
      } || host_url
    else
      puts "Ill-formed url: '#{url}'"
      nil
    end
  end

  def self.lookup_site url
    self.lookup_affiliate self.canonical_url(url)
  end

  def self.lookup_sites url
    self.lookup_affiliates self.canonical_url(url)
  end

  # Generelly we reduce the find to the shortest available subpath of a url
  def self.find_or_initialize url_or_urls, in_full=false
    urls = (url_or_urls.is_a?(String) ? [url_or_urls] : url_or_urls)
    urls = urls.map { |url| canonical_url url }.compact.uniq unless in_full
    urls.each { |url|
      siterefs = Reference.lookup_by_url 'SiteReference', url
      # siterefs = self.where url: url # Lookup the site on the exact url
      return siterefs unless siterefs.empty?
    }
    super urls.first unless urls.empty?
  end

  protected

  # Before saving, save the host from the url
  def fix_host
    if host.blank?
      begin
        uri = URI(url)
        logger.debug (self.host = uri.host)
      rescue
        return false
      end
    end
    true
  end

end

class EventReference < Reference

end
