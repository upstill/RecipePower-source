# require 'yaml'
# require 'image_reference.rb'
require 'site.rb'
require './lib/results.rb'
require './lib/html_utils.rb'

class FinderServices
  attr_accessor :finder
  
  @@DefaultFinders =
      if !Rails.env.test?
        Finder.where(site_id: nil).to_a
      else
        [
            {:label => 'URI', :selector => 'meta[property=\'og:url\']', :attribute_name => 'content'},
            {:label => 'URI', :selector => 'link[rel=\'canonical\']', :attribute_name => 'href'},
            {:label => 'URI', :selector => 'div.post a[rel=\'bookmark\']', :attribute_name => 'href'},
            {:label => 'URI', :selector => '.title a', :attribute_name => 'href'},
            {:label => 'URI', :selector => 'a.permalink', :attribute_name => 'href'},
            {:label => 'Image', :selector => 'meta[itemprop=\'image\']', :attribute_name => 'content'},
            {:label => 'Image', :selector => 'meta[property=\'og:image\']', :attribute_name => 'content'},
            {:label => 'Image', :selector => 'img.recipe_image', :attribute_name => 'src'},
            {:label => 'Image', :selector => 'img.mainIMG', :attribute_name => 'src'},
            {:label => 'Image', :selector => 'div.entry-content img', :attribute_name => 'src'},
            {:label => 'Image', :selector => 'div.post-body img', :attribute_name => 'src'},
            {:label => 'Image', :selector => 'img[itemprop=\'image\']', :attribute_name => 'src'},
            {:label => 'Image', :selector => 'link[itemprop=\'image\']', :attribute_name => 'href'},
            {:label => 'Image', :selector => 'link[rel=\'image_src\']', :attribute_name => 'href'},
            {:label => 'Image', :selector => 'img[itemprop=\'photo\']', :attribute_name => 'src'},
            {:label => 'Image', :selector => '.entry img', :attribute_name => 'src'},
            {:label => 'Image', :selector => 'img', :attribute_name => 'src'},
            {:label => 'Title', :selector => "meta[name='title']", :attribute_name => 'content'},
            {:label => 'Title', :selector => "meta[name='fb_title']", :attribute_name => 'content'},
            {:label => 'Title', :selector => "meta[property='og:title']", :attribute_name => 'content'},
            {:label => 'Title', :selector => "meta[property='dc:title']", :attribute_name => 'content'},
            {:label => 'Title', :selector => 'title'},
            {:label => 'Author', :selector => 'meta[name=\'author\']', :attribute_name => 'content'},
            {:label => 'Author', :selector => 'meta[itemprop=\'author\']', :attribute_name => 'content'},
            {:label => 'Author', :selector => 'meta[name=\'author.name\']', :attribute_name => 'content'},
            {:label => 'Author', :selector => 'meta[name=\'article.author\']', :attribute_name => 'content'},
            {:label => 'Author Link', :selector => 'link[rel=\'author\']', :attribute_name => 'href'},
            {:label => 'Description', :selector => 'meta[name=\'description\']', :attribute_name => 'content'},
            {:label => 'Description', :selector => 'meta[property=\'og:description\']', :attribute_name => 'content'},
            {:label => 'Description', :selector => 'meta[property=\'description\']', :attribute_name => 'content'},
            {:label => 'Description', :selector => 'meta[itemprop=\'description\']', :attribute_name => 'content'},
            {:label => 'Tags', :selector => 'meta[name=\'keywords\']', :attribute_name => 'content'},
            {:label => 'Site Name', :selector => 'meta[property=\'og:site_name\']', :attribute_name => 'content'},
            {:label => 'Site Name', :selector => 'meta[name=\'application_name\']', :attribute_name => 'content'},
            {:label => 'RSS Feed', :selector => 'link[type="application/rss+xml"]', :attribute_name => 'href'}
        ].collect { |attrs| Finder.new attrs }
      end

  def initialize finder=nil
    @finder = finder
  end

  # Build a finder using controller params and an optional set of extractions derived from the page
  def self.from_extractions params, extractions=nil
    # Translate the extractions into Finder results
    findings = Results.new *(extractions ? extractions.keys : [])
    findings.assert_result 'URI', params[:url] if params[:url]
    findings.assert_result 'Title', params[:title] if params[:title]
    # tagstrings = tagstring.sub(/\[(.*)\]$/, '\1').sub(/"(.*)"$/, '\1').split( '","').map(&:strip).join ','
    extractions.each { |key, value|
      findings.assert_result key, value
    } if extractions
    findings
  end

  # Follow redirects to get a Nokogiri view on a page
  def self.open_noko url

    nkdoc = nil
    loop do
      normu = normalize_url url
      uri = URI normu
      errstr = "Couldn't make sense of '#{url}' as a URI'"
      pagefile = nil
      tries = 3
      begin
        pagefile = uri.open redirect: false
      rescue OpenURI::HTTPRedirect => redirect
        uri = redirect.uri # assigned from the "Location" response header
        retry if (tries -= 1) > 0
        raise
      rescue Exception => e
        errstr = e.to_s
        if ((tries -= 1) > 0) && (redirection = errstr.sub(/[^:]*:/, '').strip)
          from, to = *redirection.split('->')
          if (from.strip == normu) && to.present?
            normu = normalize_url to.strip
            uri = URI normu
            retry
          end
        end
      end
      raise(Exception, errstr) unless pagefile

      # We've got a set of finders to apply and an open page to apply them to. Nokogiri time!
      nkdoc = Nokogiri::HTML pagefile

      # It's possible that the page returns a refresh with non-zero refresh time, tantamount to a redirect
      # We should follow this to find the ultimate page
      if (refresh_content = nkdoc.css("meta[http-equiv='refresh']")) && (refresh_content.count > 0)
        spl = refresh_content.attr('content').to_s.split ';'
        if (refresh_time = spl.first).present? && (refresh_time.match /^\s*\b0+\b\s*$/) # refresh_time == 0
          path = spl.last.sub(/^\s*url=\s*\b/, '')
          url = normalize_url safe_uri_join(normu, path).to_s
          next if url != normu
        end
      end
      break
    end
    nkdoc
  end

  # Return the raw mapping from finders to arrays of hits
  def self.glean url, site=nil, *finders_or_labels
    unless site.nil? || site.respond_to?(:finders)
      finders_or_labels.unshift site
      site = nil
    end

    # We get either a list of finders to apply, or a list of labels to look for
    finders, labels =
        finders_or_labels.first.is_a?(Finder) ?
            [finders_or_labels, []] :
            [self.finders_for(site), finders_or_labels]

    uri = URI url
    pagehome = "#{uri.scheme}://#{uri.host}"
    nkdoc = NestedBenchmark.measure('making Nokogiri request') { self.open_noko url }
    # Delete all <script> tags up front
    nkdoc.css('script').map &:remove

    # Initialize the results
    results = Results.new *finders.map(&:label)
    NestedBenchmark.measure('filtering for results with Nokogiri') do
      finders.each do |finder|
        label = finder.label
        next unless (selector = finder.selector) &&
            (labels.blank? || labels.include?(label)) && # Filter for specified labels, if any
            (matches = nkdoc.css(selector)) &&
            (matches.count > 0)
        # finder.attribute_name = finder.finder.attribute_name
        result = Result.new finder # For accumulating results
        matches.each do |ou|
          children = (ou.name == 'ul') ? ou.css('li') : [ou]
          children.each do |child|
            # If the content is enclosed in a link, emit the link too
            if attribute_value = finder.attribute_name && child.attributes[finder.attribute_name].to_s.if_present
              result.push attribute_value
            elsif finder.attribute_name == 'content'
              result.push child.content.strip
            elsif finder.attribute_name == 'html'
              result.push child.to_html, true
            elsif child.name == 'a'
              result.glean_atag finder[:linkpath], child, pagehome
            elsif child.name == 'img'
              outstr = child.attributes['src'].to_s
              result.push outstr
              # If there's an enclosed link coextensive with the content, emit the link
            elsif (atag = child.css('a').first) && (cleanupstr(atag.content) == cleanupstr(child.content))
              result.glean_atag finder[:linkpath], atag, pagehome
            else # Otherwise, it's just vanilla content
              result.push child.content.strip
            end
          end
        end
        # Make sure that URLs are properly joined
        case label
        when 'URI'
        when 'Author Link'
        when 'RSS Feed'
        when 'Image'
          result.out = result.out.collect { |url|
            begin
              url.match(/^data:/) ? url : safe_uri_join(pagehome, url).to_s
            rescue Exception => e
              nil
            end
          }.compact
        end
        if result.found
          result.report
          results[label] << result
        end
      end
    end
    results
  end

  # Analyze the error coming from a gleaning
  def self.err_breakdown url, msg
    # We assume the first three-digit number is the HTTP status code
    msg = msg.to_s
    http_status = (m=msg.match(/\b\d{3}\b/)) ? m[0].to_i : (401 if msg.match('redirection forbidden:'))

    errmsg = " #{url} failed to glean (http_status #{http_status}): #{msg}"
    { status: http_status, msg: errmsg }
  end

  # Canonicalize strings by collapsing whitespace into a single space character, and
  # eliminating spaces immediately preceding commas
  def cleanupstr (str)
    str.strip.gsub(/\s+/, ' ').gsub(/ ,/, ',') unless str.nil?
  end

  # Check that the proposed finder actually does its job by running it on a linkable entity
  def testflight entity
    begin
      results = FinderServices.glean entity.decorate.url, @finder
    rescue Exception => msg
      @finder.errors.add :url, FinderServices.err_breakdown(entity.decorate.url, msg)[:msg]
      return
    end
    if results.result_for @finder.label # Found a result on the page!
      if !entity.gleaning || entity.gleaning.assimilate_finder_results(results)
        # This was a meaningful addition to the finders
        @finder.save
      else
        @finder.errors.add :selector, 'is already in use'
      end
    else
      @finder.errors.add :selector, 'doesn\'t find anything on the page'
    end
  end

  def self.content_finder_for site_or_root, selector
    site = nil
    case site_or_root
    when String
      matching_sites = Site.where('root ILIKE ?', "%#{site_or_root}%")
      case matching_sites.count
      when 0 # No match found
        puts "Can't find a site to match #{site_or_root}"
      when 1
        site = matching_sites.first
      else
        puts "More than one site matches #{site_or_root}"
      end
    when Site
      site = site_or_root
    else
      puts "FinderServices.content_finder_for must take a site or a string that matches ONE site's root"
    end
    if site
      # Create
      self.new Finder.find_or_initialize_by(site: site, label: 'Content', selector: selector, attribute_name: 'html')
    end
  end

  # Return the set of finders that apply to the site (those assigned to the site, then global ones)
  # Optionally filter them with :only and :except options (not both)
  def self.finders_for site = nil, options = {}
    finders = (site&.finders || []) + @@DefaultFinders
    if options[:only].present?
      finders.select {|f| options[:only].include? f.label}
    elsif options[:except].present?
      finders.select {|f| !(options[:except].include? f.label)}
    else
      finders
    end
  end

  # Provide the finders in a form suitable for passing to a Javascript processor (see capture.js.erb)
  def self.js_finders site=nil, options={}
    self.finders_for(site, options).collect { |finder|
      finder.attributes.slice 'label', 'selector', 'attribute_name'
    }
  end

  def self.label_choices
    @@DataChoices ||= (@@DefaultFinders.map(&:label) + ['Site Logo', 'Content']).uniq
  end

  def self.attribute_choices
    @@AttributeChoices ||= (@@DefaultFinders.map(&:attribute_name) << 'html').uniq
  end

  def self.css_class label
    label.to_s.downcase.gsub /\s/, '-'
  end

end
