# require 'yaml'
# require 'reference.rb'
require 'site.rb'
require './lib/results.rb'

class FinderServices
  attr_accessor :finder

  def initialize finder=nil
    @finder = finder
  end

  # Return a Results structure, either using the given extractions, or by examining the page
  def self.findings extractions, url=nil
    if extractions
      # Translate the extractions into Finder results
      findings = Results.new *extractions.keys
      # tagstrings = tagstring.sub(/\[(.*)\]$/, '\1').sub(/"(.*)"$/, '\1').split( '","').map(&:strip).join ','
      extractions.each { |key, value| findings.assert_result key, value }
      findings
    elsif url
      findings = FinderServices.glean url
      findings if findings.present
    end
  end

  # Return the raw mapping from finders to arrays of hits
  def self.glean url, site=nil, *finders_or_labels
    unless site.nil? || site.is_a?(Site)
      finders_or_labels.unshift site
      site = nil
    end
    finders = finders_or_labels.first.is_a?(Finder) ? finders_or_labels : self.applicable_finders(site, *finders_or_labels)

    uri = URI url
    pagehome = "#{uri.scheme}://#{uri.host}"

    normu = normalize_url url
    begin
      pagefile = open normu
    rescue Exception => e
      errstr = e.to_s
      if redirection = errstr.sub( /[^:]*:/, '').strip
        from, to = *redirection.split('->')
        if (from.strip == normu) && to.present?
          normu = normalize_url to.strip
          begin
            pagefile = open normu
          rescue Exception => e
            errstr = e.to_s
          end
        end
      end
    end
    return unless pagefile

    # We've got a set of finders to apply and an open page to apply them to. Nokogiri time!
    nkdoc = Nokogiri::HTML pagefile

    # Initialize the results
    results = Results.new *finders.map(&:label)

    finders.each do |finder|
      label = finder.label
      next unless (selector = finder.selector) &&
          (matches = nkdoc.css(selector)) &&
          (matches.count > 0)
      attribute_name = finder.attribute_name
      result = Result.new finder # For accumulating results
      matches.each do |ou|
        children = (ou.name == 'ul') ? ou.css('li') : [ou]
        children.each do |child|
          # If the content is enclosed in a link, emit the link too
          if attribute_value = attribute_name && child.attributes[attribute_name.to_s].to_s
            result.push attribute_value
          elsif child.name == 'a'
            result.glean_atag finder[:linkpath], child, pagehome
          elsif child.name == 'img'
            outstr = child.attributes['src'].to_s
            result.push outstr unless finder[:pattern] && !(outstr =~ /#{finder[:pattern]}/)
            # If there's an enclosed link coextensive with the content, emit the link
          elsif (atag = child.css('a').first) && (cleanupstr(atag.content) == cleanupstr(child.content))
            result.glean_atag finder[:linkpath], atag, pagehome
          else # Otherwise, it's just vanilla content
            result.push child.content
          end
        end
      end
      if result.found
        result.report
        results[label] << result
      end
    end
    results
  end

  # Canonicalize strings by collapsing whitespace into a single space character, and
  # eliminating spaces immediately preceding commas
  def cleanupstr (str)
    str.strip.gsub(/\s+/, ' ').gsub(/ ,/, ',') unless str.nil?
  end

  # Check that the proposed finder actually does its job by running it on a linkable entity
  def testflight entity
    if !(results = FinderServices.glean entity.decorate.url, @finder)
      @finder.errors.add 'url', 'page can\'t be open for analysis: ' + errstr
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


  @@DefaultFinders = [
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
  ]

  @@CandidateFinders = [
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
  ]

  # Return the set of finders that apply to the site (those assigned to the site, then global ones)
  def self.applicable_finders site=nil, *labels
    if site.is_a?(String)
      labels.unshift site
      site = nil
    end
    candidates = (site ? site.finders : []) +
        # Give the DefaultFinders and CandidateFinders a unique, site-less finder from the database
        (@@DefaultFinders + @@CandidateFinders).collect { |finderspec|
          finderspec[:finder] ||= Finder.where(finderspec.slice(:label, :selector, :attribute_name).merge site_id: nil).first_or_create
        }
    if labels.present?
      candidates.keep_if { |finder| labels.include? finder.label}
    else
      candidates
    end
  end

  # Provide the finders in a form suitable for passing to a Javascript processor (see capture.js.erb)
  def self.js_finders site=nil
    self.applicable_finders(site).collect { |finder|
      finder.attributes.slice 'label', 'selector', 'attribute_name'
    }
  end

  def self.label_choices
    @@DataChoices ||= ((@@DefaultFinders+@@CandidateFinders).collect { |f| f[:label] } << 'Site Logo').uniq
  end

  def self.attribute_choices
    @@AttributeChoices ||= (@@DefaultFinders+@@CandidateFinders).collect { |f| f[:attribute_name] }.uniq
  end

  def self.css_class label
    label.downcase.gsub /\s/, '-'
  end

end
