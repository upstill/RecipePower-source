# encoding: UTF-8
require './lib/uri_utils.rb'
=begin
class Finder < Object
  attr_accessor :label, :path, :attribute
  def initialize label, path, attribute
    self.label = label
    self.path = path
    self.attribute = attribute
    super()
  end

  def self.model_name
    ActiveModel::Name.new Site::Finder
  end
end
=end

class Site < ActiveRecord::Base
  include Taggable
  # site: root of the domain (i.e., protocol + domain); suitable for pattern-matching on a reference URL to glean a set of matching Sites
  # subsite: a path relative to the domain which differentiates among Sites with the same domain (site attribute)
  # home: where the nominal site lives. This MAY be (site+subsite), but in cases of indirection, it may be an entirely
  #      different domain. (See Splendid Table on publicradio.org redirect to splendidtable.org)
  # So, (site+sample) and (site+subsite) should be valid links, but not necessarily (home+sample), since redirection
  #      may alter the path
  # Also, in most cases, site==home (when the domain is home, i.e. subsite is empty); in others, (site+subsite)==home,
  #     and only rarely will home be different from either of those
  attr_accessible :finders_attributes, :site, :home, :scheme, :subsite, :sample, :host, :name, :port, :logo, :ttlcut, :finders, :reviewed
#   serialize :finders, Array

  belongs_to :referent # See before_destroy method, :dependent=>:destroy

  has_many :finders, :dependent=>:destroy
  accepts_nested_attributes_for :finders, :allow_destroy => true
  
  has_many :feeds, :dependent=>:destroy

  # When creating a site, also create a corresponding site referent
  # before_create :ensure_referent
  
  after_initialize :post_init
  
  def perform
    feeds.each { |feed| feed.destroy if (feed.user_ids-[4]).empty? }
  end

protected

  # If this is the last site associated with its referent, destroy the referent
  before_destroy do |site|
    sibling_sites = Site.where(referent_id: site.referent_id)
    site.referent.destroy if (sibling_sites.count == 1) && (sibling_sites.first.id == site.id)
  end

  def post_init
    unless self.site
      # We need to initialize the fields of the record, starting with site, based on sample
      # Ignore the query for purposes of gleaning the site
      if link = self.sample
        breakdown = link.match /(^[^?]*)(\?.*$)?/
        linksq, query = breakdown[1..2]
        begin
          urisq = URI linksq
        rescue Exception => e
          urisq = nil
        end
        if urisq && !urisq.host.blank?
          puts "Creating host matching #{urisq.host} for #{link} with subsite \'#{self.subsite||""}\'"
          puts "Link is '#{link}'; path is '#{urisq.path}'"
          # Define the site as the link minus the sample (sub)path
          self.site = linksq.sub(/#{urisq.path}$/, "")
          puts "...from which extracted site '#{self.site}'"

          # Reconstruct the sample from the link's path, query and fragment
          self.sample = urisq.path + (query || "")

          # Save scheme, host and port information from the link parse
          self.scheme = urisq.scheme
          self.host = urisq.host
          self.port = urisq.port.to_s

          # Give the site a provisional name, the host name minus 'www.', if any
          self.name = urisq.host.sub(/www\./, '')
        else
          self.errors << "Can't make sense of URI"
        end
      end
      if !self.site
        # "Empty" site (probably defaults)
        self.site = ""
        self.subsite = ""
        self.name = "Anonymous"
      end
      self.subsite ||= ""
    end
  end

public

  def domain
    scheme+"://"+host+((port=="80") ? "" : (":"+port))
  end

  def sampleURL
    self.site+(self.sample||"")
  end

  # By default the site's home page is (site+subsite), but that may be overridden (due to indirection) by
  # setting the home attribute
  def home_page
    home.blank? ? (site+(subsite||"")) : home
  end
  
  # Find and return the site wherein the named link is stored
  def self.by_link (link, all=false)
    # Sanitize the URL
    link.strip!
    link.gsub!(/\{/, '%7B')
    link.gsub!(/\}/, '%7D') 
    begin
      uri = URI link
    rescue Exception => e
      uri = nil
    end
    if uri && !uri.host.blank?
      # Find all sites assoc'd with the given domain
      sites = Site.where "host = ?", uri.host
      # If multiple sites may proceed from the same domain, 
      # we need to find the one whose full site path (site+subsite) matches the link
      # So: among matching hosts, find one whose 'site+subsite' is an initial substring of the link
      matching_subsites = []; matching_sites = []
      sites.each do |site|
        unless site.site.empty?
          matching_sites << site if link.index(site.site)
          matching_subsites << site if !site.subsite.empty? && link.index(site.site+site.subsite)
        end
      end
      all ? (matching_sites+matching_subsites).uniq : (matching_subsites[0] || matching_sites[0] || Site.create(:sample=>link))
    else
      puts "Ill-formed link: '#{link}'"
      nil
    end
  end

  def name
    referent.name
  end

  def name=(str)
    if referent
      referent.express(str, :tagtype => :Source, :form => :generic )
    else
      self.referent = Referent.express(str, :Source, :form => :generic )
    end
  end      
  
  def recipes
    stripped_host = (host =~ /^www./) ? host[4..-1] : host
    Recipe.where('url LIKE ?', "%#{stripped_host}%")
  end
end

=begin
Title:
	title:
		'cut': " - Calabria from scratch"
		'count': "269"
		--------------------------------------
		'cut': "spicy icecream: "
		'count': "269"
		--------------------------------------
		'cut': " Recipe \| Steamy Kitchen Recipes"
		'count': "269"
		--------------------------------------
		'cut': " \| RecipeGirl.com"
		'count': "269"
		--------------------------------------
		'count': "269"
		--------------------------------------
	meta[property='og:title']:
		'attribute': "content"
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': " - Drink Recipe.*"
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': "Recipe: "
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': " Recipe.*$"
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': "How to Make.*- "
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': "IDEAS IN FOOD: "
		'count': "122"
		--------------------------------------
		'attribute': "content"
		'cut': " recipe"
		'count': "122"
		--------------------------------------
	.fn:
		'count': "96"
		--------------------------------------
	span.fn:
		'count': "55"
		--------------------------------------
	tr td div:
		'count': "52"
		--------------------------------------
	.title a:
		'count': "36"
		--------------------------------------
	h1.title:
		'count': "28"
		--------------------------------------
	meta[name='title']:
		'attribute': "content"
		'count': "22"
		--------------------------------------
	h2 a[rel='bookmark']:
		'count': "13"
		--------------------------------------
	div.post h2 a[rel='bookmark']:
		'count': "11"
		--------------------------------------
	#title:
		'count': "11"
		--------------------------------------
	h3.entry-title a:
		'count': "7"
		--------------------------------------
	meta[property='dc:title']:
		'attribute': "content"
		'count': "3"
		--------------------------------------
	.recipe .title:
		'count': "3"
		--------------------------------------
	#zlrecipe-title:
		'count': "2"
		--------------------------------------
	.storytitle:
		'count': "2"
		--------------------------------------
	#recipe_title:
		'count': "1"
		--------------------------------------
	#page-title-link:
		'count': "1"
		--------------------------------------
	#main-article-info h1:
		'cut': " recipe"
		'count': "1"
		--------------------------------------
	#maincontent .content h2 a[rel='bookmark']:
		'count': "1"
		--------------------------------------
	#article-body-blocks h2:
		'count': "0"
		--------------------------------------
Image:
	img:
		'count': "261"
		--------------------------------------
	meta[property='og:image']:
		'attribute': "content"
		'count': "113"
		--------------------------------------
	img.photo:
		'count': "63"
		--------------------------------------
	div.entry-content a img:
		'count': "50"
		--------------------------------------
	table img:
		'attribute': "alt"
		'count': "44"
		--------------------------------------
	img.size-full:
		'count': "38"
		--------------------------------------
	.entry img:
		'count': "36"
		--------------------------------------
	img.aligncenter:
		'count': "29"
		--------------------------------------
	.post-body img:
		'count': "20"
		--------------------------------------
	img[itemprop='image']:
		'attribute': "src"
		'count': "15"
		--------------------------------------
		'count': "15"
		--------------------------------------
	div.post div.entry a:first-child img:first-child:
		'count': "14"
		--------------------------------------
	img[itemprop='photo']:
		'count': "5"
		--------------------------------------
	div.holder img:
		'count': "4"
		--------------------------------------
	img.recipe_image:
		'count': "2"
		--------------------------------------
	a#recipe-image:
		'attribute': "href"
		'count': "1"
		--------------------------------------
	div.featRecipeImg img:
		'count': "1"
		--------------------------------------
	div.photo img[itemprop='image']:
		'count': "1"
		--------------------------------------
	#drink_infopicvid img:
		'count': "1"
		--------------------------------------
	.listing-photo img:
		'count': "1"
		--------------------------------------
	a[rel='modal-recipe-photos'] img:
		'count': "1"
		--------------------------------------
	.hfeed .featured-img img:
		'count': "1"
		--------------------------------------
	.storycontent img:
		'count': "1"
		--------------------------------------
	#picture img:
		'count': "1"
		--------------------------------------
	#recipe-image:
		'attribute': "href"
		'count': "1"
		--------------------------------------
	#main-content-picture img:
		'count': "1"
		--------------------------------------
	div.box div.post div.entry a img:
		'attribute': "src"
		'count': "1"
		--------------------------------------
	.landscape-image img:
		'count': "1"
		--------------------------------------
	#rec-photo img:
		'count': "0"
		--------------------------------------
	link[rel='image_source']:
		'attribute': "href"
		'count': "0"
		--------------------------------------
	img#photo-target:
		'count': "0"
		--------------------------------------
	img.mainIMG:
		'count': "0"
		--------------------------------------
	#photo-target:
		'count': "0"
		--------------------------------------
	.tdm_recipe_image img[itemprop='image']:
		'attribute': "src"
		'count': "0"
		--------------------------------------
	div.recipe-image-large img:
		'count': "0"
		--------------------------------------
	td img:
		'pattern': "images/food/"
		'count': "0"
		--------------------------------------
URI:
	link[rel='canonical']:
		'attribute': "href"
		'count': "170"
		--------------------------------------
	meta[property='og:url']:
		'attribute': "content"
		'count': "114"
		--------------------------------------
	.post a[rel='bookmark']:
		'attribute': "href"
		'count': "46"
		--------------------------------------
	.title a:
		'attribute': "href"
		'count': "37"
		--------------------------------------
	input[name='uri']:
		'attribute': "value"
		'count': "17"
		--------------------------------------
	div.post h2 a[rel='bookmark']:
		'attribute': "href"
		'count': "11"
		--------------------------------------
	a.permalink:
		'attribute': "href"
		'count': "10"
		--------------------------------------
	a.addthis_button_pinterest:
		'attribute': "pi:pinit:url"
		'count': "3"
		--------------------------------------
	.hrecipe a[rel='bookmark']:
		'attribute': "href"
		'count': "3"
		--------------------------------------
	#recipe_tab:
		'attribute': "href"
		'count': "2"
		--------------------------------------
	div.hrecipe a[rel='bookmark']:
		'attribute': "href"
		'count': "1"
		--------------------------------------
=end
