require 'net/http'
# A MercuryPage is a record for storing the Mercury (nee Readability) summary of a Web page.
# Besides storing the result of the query (which, after all, could be re-instantiated at any time)
# the class deals with multiple URLs leading to the same page. That is, since Mercury extracts a
# canonical URL, many URLs could lead to that single referent.
class MercuryPage < ActiveRecord::Base
  # after_initialize :fetch

  @@attribs = [:url, :title, :content, :date_published, :lead_image_url, :domain, :author]
  @@extraneous_attribs = [ :dek, :excerpt, :word_count, :direction, :total_pages, :rendered_pages, :next_page_url ]

  attr_accessible *@@attribs

  # serialize :aliases
  store :extraneity, accessors: @@extraneous_attribs, coder: JSON

  def initialize url

    super()

    uri = URI.parse 'https://mercury.postlight.com/parser?url=' + url
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Get.new uri.to_s
    req['x-api-key'] = ENV['MERCURY_API_KEY'] # "CCCt8Pvy1dERUwikic1JFuaWnAts9epV11qZIgtZ"

    begin
      response = http.request req

      data = JSON.parse response.body
      self.extraneity = data.slice(*(@@extraneous_attribs.map(&:to_s)))
      self.assign_attributes data.slice(*(@@attribs.map(&:to_s)))
      self.aliases << url if (data['url'] != url && !aliases.include?(url)) # Record the url in the aliases if not already there
    rescue Exception => e
      self.errors.add :url, message: 'Bad URL'
    end
  end

  # String => MercuryPage
  # Return a (possibly newly-created) MercuryPage on the given URL
  # NB Since the derived canonical URL may differ from the given url,
  # the returned record will not have the same url as the request
  def self.fetch url
    url.sub! /\#[^#]*$/, ''
    unless (mp = self.find_by(url: url) || self.find_by("'#{url}' = ANY(aliases)"))
      mp = MercuryPage.new url
      unless mp.errors.any?
        if MercuryPage.exists?(url: mp.url) # Check for duplicate URL
          # Fold the extracted page data into the existing page
          mp = MercuryPage.find_by(url: mp.url)
          mp.aliases |= [url]
        end
        mp.save
    end
  end
    mp
  end
end
