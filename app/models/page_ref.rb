require 'net/http'
# A PageRef is a record for storing the Mercury (nee Readability) summary of a Web page.
# Besides storing the result of the query (which, after all, could be re-instantiated at any time)
# the class deals with multiple URLs leading to the same page. That is, since Mercury extracts a
# canonical URL, many URLs could lead to that single referent.
class PageRef < ActiveRecord::Base
  # after_initialize :fetch

  @@attribs = [:url, :title, :content, :date_published, :lead_image_url, :domain, :author]
  @@extraneous_attribs = [ :dek, :excerpt, :word_count, :direction, :total_pages, :rendered_pages, :next_page_url ]

  attr_accessible *@@attribs, :type, :error_message

  has_many :referments, :as => :referee

  # The site for a page_ref is the Site object with the longest root matching the canonical URL
  belongs_to :site

  # serialize :aliases
  store :extraneity, accessors: @@extraneous_attribs, coder: JSON

  def initialize url

    super()

    uri = URI.parse 'https://mercury.postlight.com/parser?url=' + url
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Get.new uri.to_s
    req['x-api-key'] = "CCCt8Pvy1dERUwikic1JFuaWnAts9epV11qZIgtZ" # ENV['MERCURY_API_KEY'] #

    begin
      response = http.request req

      data = JSON.parse response.body
      if (self.error_message = data['errorMessage']).present?
        self.errors.add :url, "Error on fetch of #{url}: #{data['errorMessage']}"
        self.url = url
      else
      data['content'].tr! "\x00", ' ' # Mercury can return strings with null bytes for some reason
      self.extraneity = data.slice(*(@@extraneous_attribs.map(&:to_s)))
      self.assign_attributes data.slice(*(@@attribs.map(&:to_s)))
      self.aliases << url if (data['url'] != url && !aliases.include?(url)) # Record the url in the aliases if not already there
      end
    rescue Exception => e
      self.errors.add :url, message: 'Bad URL'
    end
  end

  # String => MercuryPage
  # Return a (possibly newly-created) MercuryPage on the given URL
  # NB Since the derived canonical URL may differ from the given url,
  # the returned record will not have the same url as the request
  def self.fetch url
    url.sub! /\#[^#]*$/, '' # Elide the target for purposes of finding
    unless (mp = self.find_by(url: url) || self.find_by("'" + url.gsub("'", "''") + "' = ANY(aliases)"))
      mp = self.new url
      unless mp.errors.any?
        if extant = self.find_by(url: mp.url) # Check for duplicate URL
          # Found => fold the extracted page data into the existing page
          extant.aliases |= mp.aliases - [ extant.url ]
          mp = extant
        end
        mp.save
      end
    end
    mp
  end

end

class RecipePageRef < PageRef
  attr_accessible :recipes

  has_many :recipes, foreign_key: 'page_ref_id', :dependent => :nullify

# The former RecipeReference.lookup_recipe
  def self.recipe url
    self.lookup_affiliate url
  end

  def self.recipes_from_site url
    self.affiliates_scope url
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
              next if File.exist?(path) || RecipeReference.lookup(url).exists?

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

class SitePageRef < PageRef

end

class DefinitionPageRef < PageRef

end

class ArticlePageRef < PageRef

end

class NewsitemPageRef < PageRef

end

class TipPageRef < PageRef

end

class VideoPageRef < PageRef

end

class HomepagePageRef < PageRef

end

class ProductPageRef < PageRef

end

class OfferingPageRef < PageRef

end

class EventPageRef < PageRef

end
