# require 'active_support/hash_with_indifferent_access.rb'
# The scraper class exists to scrape pages: one per scraper. The scraper either:
# 1) generates more scrapers based on the contents of the page, or
# 2) finds data and adds that to the RecipePower database
# Attributes:
# url: the url of the page to be examined
# site: the site being examined, expressed as the name of a method of the scraper model
# what: the contents that are being sought (a section of the method that scrapes this kind of page)
# data: a JSON dataset that may be passed down the scrape tree
class Scraper < ActiveRecord::Base

  attr_accessible :url, :what, :subclass, :data, :run_at, :waittime, :errcode, :recur

  serialize :data

  attr_accessor :mechanize

  def self.assert url, *args # what, recur=true, data={}
    uri = normalized_uri CGI.unescape(url)
    subclass = (uri.host.capitalize.split('.') << 'Scraper').join('_')

    what = subclass.constantize.handler uri
    recur = true
    data = {}
    if args.present?
      if args.first.is_a?(String) || args.first.is_a?(Symbol)
        what = args.shift
      end

      if args.first.is_a? Hash
        data = args.shift
      else
        recur = args.shift
        data = args.first if args.present?
      end
    end

    scraper = self.find_or_initialize_by url: uri.to_s, what: what, subclass: subclass
    scraper.recur = recur
    scraper.data = data
    scraper
  end

  # perform with error catching
  def perform
    begin
      perform_naked
    rescue Exception => e
      fail e
    end
  end

  def perform_naked
    STDERR.puts ">> Performing #{what} on #{url}"

    self.becomes(subclass.constantize).send what.to_sym
    self.errcode = errors.any? ? -1 : 0 # Successful
    save
  end

  # Pitch the scraper into the DelayedJob queue
  def queue_up
    # Defer till later
    maxwait = self.class.maximum('waittime') || 1
    # The strategy here: double the wait time as jobs fail
    self.waittime = (waittime < maxwait) ? maxwait : (maxwait*2)
    self.run_at = (self.class.maximum('run_at') || Time.now) + waittime.seconds
    STDERR.puts "<< Queueing #{what} on #{url} after #{waittime} to run at #{run_at}"
    save
    Delayed::Job.enqueue self, priority: 20, run_at: run_at
  end

  def fail error
    rcode = error.respond_to?(:response_code) ? error.response_code.to_i : -1
    case rcode
      when 503
        if id
          queue_up
          return
        else
          error = "Host isn't talking at the moment"
        end
      when 404
        error = 'doesn\'t point to anything!'
    end
    self.errcode = rcode
    errors.add :url, error.to_s
    save if id
  end

  def launch link_or_links, what, data=self.data
    [link_or_links].flatten.compact.each { |link|
      link = absolutize link # A Mechanize object for a link
      if recur

        STDERR.puts "** Launching #{what} on #{link}"
        scraper = Scraper.assert link, what, data
        data.immediate ? scraper.perform : scraper.queue_up
      else
        STDERR.puts "** WOULD BE Launching #{what} (handler says #{self.class.handler link}) on #{link}"
      end
    }
  end

  def absolutize link_or_path
    if path = link_or_path.is_a?(String) ? link_or_path : (link_or_path.href if link_or_path.respond_to? :href)
      URI.join(url, path).to_s
    else
      url
    end
  end

  def mechanize
    return @mechanize if @mechanize

    @mechanize = Mechanize.new
    @mechanize.user_agent_alias = 'Mac Safari'
    @mechanize
  end

  # Get the page data via Mechanize
  def page
    return @page if @page

    STDERR.puts "** Getting page #{url}"
    @page = mechanize.get url
  end

  def uri
    # Sanitized, for your protection
    return @uri if @uri
    if @uri = normalized_uri(url)
      self.url = @uri.to_s
    else
      errors.add :url, 'cannot be understood (is not a valid URL)'
    end
    @uri
  end

  def find selector, attribute_name=nil
    if s = page.search(selector).first
      found = attribute_name ? s.attributes[attribute_name.to_s] : s.text
      STDERR.puts "!! ...found in #{selector}: '#{found}'"
      found.to_s
    end
  end

  # Declare a tag of the given type, with a matching DefinitionReference (perhaps to the current page).
  # NB: This is all we need to produce a Referent
  def define tagtype, tagname, href=nil
    tag = Tag.assert tagname, tagtype: tagtype
    STDERR.puts "!! ...found #{tagtype.to_s.downcase} link to #{tagname} (Tag ##{tag.id}) at #{href || url}"
    Reference.assert absolutize(href), tag, :Definition
    tagname
  end
end

class Www_bbc_co_uk_Scraper < Scraper

  # Predict what handler will scrape the page
  def self.handler url_or_uri
    uri = url_or_uri.is_a?(String) ? (normalized_uri CGI.unescape(url_or_uri)) : url_or_uri
    case [uri.path, uri.query].compact.join('?')
      when /\A\/food\/chefs\z/
        :chefs
      when /\A\/food\/chefs\/by\/letters\//
        :atoz_page
      when /\A\/food\/chefs\/\w+\z/
        :chef_page
      when /\A\/food\/recipes\/search\?.*chefs(\[[^\]]*\]=|\/)([^&]*)/
        :chef_recipes_page
      when /\A\/food\/recipes\/\w+\z/
        :recipe_page
      when /\A\/food\/ingredients\/by\/letter\z/
        :ingredient_letters
      when /\A\/food\/ingredients\/by\/letter\/[a-z]\z/
        :ingredients_by_letter
      when /\A\/food\/\w+\z/
        uri.fragment == 'related-foods' ? :related_ingredients : :ingredient_page
    end
  end

  ########## Recipes, by chef #####################
  def chefs # Top level of chef scraping
    launch page.links_with(href: /\/by\/letters\//), :atoz_page
  end

  def atoz_page
    chef_ids = page.links_with(href: /\A\/food\/chefs\/\w+\z/).collect { |link|
      link.href.split('/').last
    }.compact
    launch chef_ids.collect { |chef_id|
             'http://www.bbc.co.uk/food/chefs/' + chef_id
           }, :chef_page
    launch chef_ids.collect { |chef_id|
             'http://www.bbc.co.uk/food/recipes/search?chefs[]=' + chef_id
           }, :chef_recipes_page
  end

  def chef_page
    unless m = url.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
      errors.add :url, 'doesn\'t match the format of a chefs page'
      return
    end

    if (s = page.search 'h1.fn') && s.first
      define 'Author', s.first.content, url
    end

  end

  def chef_recipes_page
    # The id of the chef is embedded in the query
    unless m = url.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
      errors.add :url, 'doesn\'t match the format of a chefs page'
      return
    end

    chef_id = m[2].to_s


    launch page.links_with(href: /\A\/food\/recipes\/\w+\z/),
           :recipe_page,
           data.merge(chef_id: chef_id)
    launch page.links.detect { |link| link.rel?('next') }, :chef_recipes_page
  end

  def recipe_page

    if uri
      # Glean title, description and image
      extractions = HashWithIndifferentAccess.new(
          :Title => find("meta[property='og:title']", :content),
          :Description => find("meta[property='og:description']", :content),
          :Image => find("meta[property='og:image']", :content)
      )

      chef_id = data[:chef_id]
      if link = page.link_with(dom_class: 'chef__link')
        chef_id ||=
            if m = link.href.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
              m[2].to_s
            end
        extractions['Author Name'] = define 'Author', link.to_s, link.href
      end

      # Glean ingredient links from the page, meanwhile ensuring the tag is defined
      extractions[:Ingredients] = page.links_with(dom_class: 'recipe-ingredients__link').collect { |link|
        define 'Ingredient', link.to_s, link.href
      }.join ', '

      params = {url: url}
      recipe = CollectibleServices.find_or_create params, extractions.compact, Recipe

      # Ensure the output directory exists
      dirname = File.join '/var/www/RP/files/chefs', chef_id
      FileUtils.mkdir_p dirname

      hpath = uri.path
      fpath = File.join(dirname, File.basename(hpath) + '.html')

      STDERR.puts "+ #{hpath} => #{fpath}"

      unless File.exist?(fpath)
        # @mechanize.download(hpath, fpath)
        if ref = Reference.lookup_by_url('RecipeReference', url).first
          ref.filename = fpath
          ref.save
        else
          RecipeReference.create url: url, filename: fpath
        end
      end
    end
  end

  ######### Ingredients ############
  def ingredient_letters
    launch ('a'..'z').to_a.collect { |letter|
             'http://www.bbc.co.uk/food/ingredients/by/letter/' + letter
           }, :ingredients_by_letter
  end

  def ingredients_by_letter
    ingredient_links = find('li.resource.food a', :href)
    ingredient_links.each { |link|
      launch link, (link.match(/\A\/food\/\w+#related-foods\z/) ? :related_ingredients : :ingredient_page )
    }
=begin
    launch page.links_with(href: /\A\/food\/\w+\z/).map { |link|
             foodname = link.href.split('/').last
             'http://www.bbc.co.uk/food/' + foodname
           }, :ingredient_page
    launch page.links_with(href: /\A\/food\/\w+#related-foods\z/).map { |link|
             foodname = link.href.split('/').last.split('#').first
             'http://www.bbc.co.uk/food/' + foodname + '#related-foods'
           }, :related_ingredients
=end
  end

  def ingredient_page
    if img = find 'img#food-image', :src
      x=2
    end
  end

  def related_ingredients

  end
end
