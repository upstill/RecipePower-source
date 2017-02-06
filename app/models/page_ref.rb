require 'net/http'
# A PageRef is a record for storing the Mercury (nee Readability) summary of a Web page.
# Besides storing the result of the query (which, after all, could be re-instantiated at any time)
# the class deals with multiple URLs leading to the same page. That is, since Mercury extracts a
# canonical URL, many URLs could lead to that single referent.
class PageRef < ActiveRecord::Base

  validates_each :url do |pr, attr, value|
    pr.errors.add :url, "'#{pr.url}' (PageRef ##{pr.id}) is not a valid URL" unless pr.good? || validate_link(pr.url, %w{ http https }) # Is it a valid URL?
  end

  include Backgroundable
  backgroundable

  @@mercury_attributes = [:url, :title, :content, :date_published, :lead_image_url, :domain, :author]
  @@extraneous_attribs = [ :dek, :excerpt, :word_count, :direction, :total_pages, :rendered_pages, :next_page_url ]

  attr_accessible *@@mercury_attributes, :type, :error_message, :http_status

  attr_accessor :extant_prid

  # The site for a page_ref is the Site object with the longest root matching the canonical URL
  belongs_to :site

  before_save do |pr|
    if (pr.class != SitePageRef) && (pr.url_changed? || !pr.site) && pr.url.present?
      puts "Find/Creating Site for PageRef ##{pr.id} w. url '#{pr.url}'"
      pr.site = Site.find_or_create_for(pr.url)
    end
  end

  # serialize :aliases
  store :extraneity, accessors: @@extraneous_attribs, coder: JSON

  # What attributes are obtained from Mercury?
  def self.mercury_attributes
    @@mercury_attributes + [ :extraneity ]
  end

  def perform
    bkg_execute {
      begin
        sync
      rescue Exception => err
        # Failed to complete properly
        err = ([err] + errors.full_messages).join "\n\t"
        self.error_message = "Fatal error in PageRef#sync: #{err}"
        self.http_status = 666
        self.status = :bad
        false
      end
    }
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
  def sync
    extant_prid = nil
    begin
      data = try_mercury url
      self.http_status =
          if (self.error_message = data['errorMessage']).blank?
            200
          else
            # Check the header for the url from the server.
            # If it's a string, the header returned a redirect
            # otherwise, it's an HTTP code
            puts "Checking direct access of PageRef ##{id} at '#{url}'"
            redirected_from = nil
            while hr = header_result(data['url'])
              if hr.is_a?(Fixnum)
                data['url'] = self.aliases.delete(redirected_from) if (hr == 404) && redirected_from
                break;
              end
              hr = URI.join(data['url'], hr).to_s unless hr.match(/^http/) # The redirect URL may only be a path
              break if aliases.include?(hr)
              puts "Redirecting from #{data['url']} to #{hr}"
              begin
                self.aliases |= [redirected_from = data['url']] # Stash the redirection source in the aliases
                data = try_mercury hr
                if (self.error_message = data['errorMessage']).blank? # Success on redirect
                  hr = 200
                  break;
                end
              rescue Exception => e
                # Bad URL => Restore the last alias
                data['url'] = self.aliases.delete(redirected_from) if redirected_from
                hr = 400
              end
            end
            hr.is_a?(String) ? 666 : hr
          end
      # Did the url change to a collision with an existing PageRef of the same type?
      if (data['url'] != url) && (extant_prid = self.class.where(url: data['url']).pluck(:id).first)
        self.error_message = "Sync'ing #{self.class} ##{id} (#{url}) failed; tried to assert existing url '#{data['url']}'"
        puts error_message
        self.http_status = 666
        data['url'] = url
        errors.add :url, "has already been taken by #{self.class} #{extant_prid}"
      end
      data['content'] ||= ''
      data['content'].tr! "\x00", ' ' # Mercury can return strings with null bytes for some reason
      self.extraneity = data.slice(*(@@extraneous_attribs.map(&:to_s)))
      self.aliases << url if (data['url'] != url && !aliases.include?(url)) # Record the url in the aliases if not already there
      self.assign_attributes data.slice(*(@@mercury_attributes.map(&:to_s)))
    rescue Exception => e
      self.errors.add :url, "Bad URL '#{url}': #{e}"
      self.http_status = 400
    end
    # We record the status here, in case we're being called outside the background mechanism
    self.status = (errors.any? || error_message.present?) ? :bad : :good
    good?
  end

  def try_mercury url
    uri = URI.parse 'https://mercury.postlight.com/parser?url=' + url
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Get.new uri.to_s
    req['x-api-key'] = ENV['MERCURY_API_KEY']

    response = http.request req

    data = JSON.parse(response.body) rescue HashWithIndifferentAccess.new(url: url, content: '', errorMessage: 'Empty Page')

    # Do QA on the reported URL
    uri = data['url'].present? ? URI.join(url, data['url']) : URI.parse(url) # URL may be relative, in which case parse in light of provided URL
    data['url'] = uri.to_s
    data['domain'] ||= uri.host
    data
  end

  def table
    self.arel_table
  end

  # Use arel to generate a query (suitable for #where or #find_by) to match the url
  def self.url_query url
    url = url.sub /\#[^#]*$/, '' # Elide the target for purposes of finding
    url_node = self.arel_table[:url]
    url_query = url_node.eq(url)
    aliases_node = self.arel_table[:aliases]
    aliases_query = aliases_node.overlap [url]
    url_query.or(aliases_query)
  end

  # Use arel to generate a query (suitable for #where or #find_by) to match the url path
  def self.url_path_query(urlpath)
    urls = [ "http://#{urlpath}%", "https://#{urlpath}%" ]
    url_node = self.arel_table[:url]
    url_query = url_node.matches("http://#{urlpath}%").or url_node.matches("https://#{urlpath}%")
  end

  def self.find_by_url url
    self.find_by(url_query url)
  end

  # String => PageRef
  # Return a (possibly newly-created) PageRef on the given URL
  # NB Since the derived canonical URL may differ from the given url,
  # the returned record may not have the same url as the request
  def self.fetch url
    url.sub! /\#[^#]*$/, '' # Elide the target for purposes of finding
    unless mp = self.find_by(self.url_query url)
      mp = self.new url: url
      mp.sync
      if !mp.errors.any? || mp.extant_prid
        if extant = mp.extant_prid ? self.find(extant_prid) : self.find_by(url: mp.url) # Check for duplicate URL
          # Found => fold the extracted page data into the existing page
          extant.aliases |= mp.aliases - [extant.url]
          mp = extant
        end
      end
    end
    mp
  end

end

class RecipePageRef < PageRef
  attr_accessible :recipes

  has_many :recipes, foreign_key: 'page_ref_id', :dependent => :nullify

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
  attr_accessible :sites

  has_many :sites, foreign_key: 'page_ref_id', :dependent => :nullify
  # belongs_to :site, foreign_key: 'affiliate_id'
  # before_save :fix_host

  # alias_method :host, :domain
  def host
    domain
  end

end

class ReferrablePageRef < PageRef
# Referrable page refs are referred to by, e.g., a glossary entry for a given concept
  include Referrable

end

class DefinitionPageRef < ReferrablePageRef

end

class ArticlePageRef < ReferrablePageRef

end

class NewsitemPageRef < ReferrablePageRef

end

class TipPageRef < ReferrablePageRef

end

class VideoPageRef < ReferrablePageRef

end

class HomepagePageRef < ReferrablePageRef

end

class ProductPageRef < ReferrablePageRef

end

class OfferingPageRef < ReferrablePageRef

end

class EventPageRef < ReferrablePageRef

end
