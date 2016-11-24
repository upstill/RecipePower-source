# String -> Hash
# Use Mercury to scrape a web page, returning a Hash with the following fields:
=begin
    "title": e.g. "An Ode to the Rosetta Spacecraft as It Flings Itself Into a Comet",
    "content": e.g. "<div><article class="content body-copy"> <p>Today, the European Space Agency’s... ",
    "date_published": e.g. "2016-09-30T07:00:12.000Z",
    "lead_image_url": e.g. "https://www.wired.com/wp-content/uploads/2016/09/Rosetta_impact-1-1200x630.jpg",
    "dek": e.g. "Time to break out the tissues, space fans.",
    "url": e.g. "https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/",
    "domain": e.g. "www.wired.com",
    "excerpt": e.g. "Time to break out the tissues, space fans.",
    "word_count": e.g. 1031,
    "direction": e.g. "ltr",
    "total_pages": e.g. 1,
    "rendered_pages": e.g. 1,
    "next_page_url": e.g. null
=end
require 'net/http'

class MercuryData < Object
  attr_accessor :title, :content, :date_published, :lead_image_url, :dek, :url, :domain, :excerpt,
                :word_count, :direction, :total_pages, :rendered_pages, :next_page_url

  def initialize url

    uri = URI.parse 'https://mercury.postlight.com/parser?url=' + url
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Get.new uri.to_s
    req['x-api-key'] = "CCCt8Pvy1dERUwikic1JFuaWnAts9epV11qZIgtZ" # ENV['MERCURY_API_KEY']

    begin
      response = http.request req
    rescue Exception => e
      nil
    end

    data = JSON.parse response.body
    self.title = data['title']
    self.url = url
  end
end