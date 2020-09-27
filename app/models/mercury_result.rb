class MercuryResult < ApplicationRecord
  include Backgroundable

  backgroundable :status

  include Trackable
  attr_trackable :url, :domain, :title, :date_published, :author, :content, :picurl, :description, :mercury_error, :new_aliases
  # Provide access methods for unpersisted results
  attr_accessor :dek, :next_page_url, :word_count, :direction, :total_pages, :rendered_pages

  has_one :page_ref, :dependent => :nullify
  has_one :site, :through => :page_ref

  serialize :results, Hash

  # Provide the attribute that will receive the value for the given Mercury result name
  def self.attribute_for_result result_name
    case result_name
    when :lead_image_url
      :picurl
    when :excerpt
      :description
    else
      result_name
    end
  end

  def adopt_dependencies
    return unless good?
    # Use the data from Mercury to set all needed keys
    results.keys.map(&:to_sym).each do |result_name|
      attr = MercuryResult.attribute_for_result result_name
      accept_attribute attr, results[result_name.to_s] if MercuryResult.tracked_attributes.include?(attr)
    end
    # Should we really be declaring that no more attributes are needed?
    clear_needed_attributes
  end

  def perform
    self.error_message = nil
    self.results = get_mercury_results
  end

  def url
    super.if_present || page_ref&.url
  end

  private

  # Consult Mercury on a url and report the results in the model
  # status: :good iff Mercury could get through to the resource, :bad otherwise
  # http_status: 200 if Mercury could get through to the resource OR the HTTP code (from the header) for a direct fetch
  # errors: set a URL error iff the URL can't be parsed by URI, in which case the model shouldn't be saved and will
  #     likely throw a validation error
  # Note that even if Mercury can crack the page, that's no guarantee that any metadata except the URL and domain are valid
  # The purpose of http_status is a positive indication that the page can be reached
  # The purpose of errors are to show that the URL is ill-formed and the record should not (probably cannot) be saved.
  def get_mercury_results
    new_aliases = [] # We accumulate URLs that got redirected on the way from the nominal URL to the final one (whether successful or not)
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
              if hr.is_a?(Integer)
                if (hr == 404) && redirected_from
                  # Got a redirect via Mercury, but the target failed
                  mercury_data['url'] = new_aliases.delete redirected_from
                  # mercury_data['url'] = elide_alias redirected_from
                  # hr = 303
                end
                break
              end
              hr = safe_uri_join(mercury_data['url'], hr).to_s unless hr.match(/^http/) # The redirect URL may only be a path
              if page_ref&.alias_for hr # Time to give up when the url has been tried (it already appears among the aliases)
                # Report the error arising from direct access
                hr = header_result hr
                break
              end
              puts "Redirecting from #{mercury_data['url']} to #{hr}"
              begin
                new_aliases << (redirected_from = mercury_data['url'])
                # alias_for((redirected_from = mercury_data['url']), true) # Stash the redirection source in the aliases
                # self.aliases |= [redirected_from = mercury_data['url']]
                mercury_data = try_mercury hr
                if mercury_data['mercury_error'].blank? # Success on redirect
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
      mercury_data['content'] = mercury_data['content']&.tr "\x00", ' ' # Mercury can return strings with null bytes for some reason
      mercury_data['new_aliases'] = new_aliases
      return mercury_data
    rescue Exception => e
      errors.add :url, "'#{url}' is bad: #{e}"
      self.http_status = 400
    end
  end

  # We're using a self-hosted Mercury: https://babakfakhamzadeh.com/replacing-postlights-mercury-scraping-service-with-your-self-hosted-copy/
  def try_mercury url
    data = mercury_via_node url
    # data = Rails.env.development? ? mercury_via_api(url) : mercury_via_node(url)

    # Do QA on the reported URL
    # Report a URL as extracted by Mercury (if any), or the original URL (if not)
    uri = data['url'].present? ? safe_uri_join(url, data['url']) : URI.parse(url) # URL may be relative, in which case parse in light of provided URL
    data['url'] = uri.to_s
    data['domain'] ||= uri.host
    # Merge different error states into a mercury_error
    data['mercury_error'] = data['errorMessage'].if_present || (data['message'] if data['error'])
    data.delete :errorMessage
    data.delete :error
    data
  end

=begin
  # Archaic: get the mercury data from our server
  def mercury_via_api url
    previous_probe = nil
    api = 'http://173.255.245.80:8888/mercury?url='
    current_probe = api + url
    data = response = nil
    while(previous_probe != current_probe) do
      uri = URI.parse current_probe
      previous_probe = current_probe
      http = Net::HTTP.new uri.host, uri.port
      # http.use_ssl = true
      response =
          NestedBenchmark.measure('making Mercury request') do
            req = Net::HTTP::Get.new uri.to_s
            req['x-api-key'] = ENV['MERCURY_API_KEY']
            http.request req
          end
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
    data['response_code'] = response.code
    data
  end
=end

  # Get the Mercury-ized page by hitting node.js directly (in production)
  def mercury_via_node url
    apphome = Rails.env.production? ? ENV['HOME'] : (ENV['HOME']+'/Dev')
    cmd = "node #{apphome}/mercury/fetch.js #{url}"
    logger.debug "Invoking '#{cmd}'"
    content = `#{cmd}`
    logger.debug "...got #{content.length} bytes from Mercury, starting with '#{content.truncate 100}'."
    data = JSON.parse content
    data['url'] = url
    data
  end

end
