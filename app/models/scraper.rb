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

  protected

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

  # Define a scraper to follow a link or links and return it, for whatever purpose
  def launch link_or_links, what, data=self.data
    [link_or_links].flatten.compact.collect { |link|
      link = absolutize link # A Mechanize object for a link
      scraper = Scraper.assert link, what, recur, data
      (data[:immediate] ? scraper.perform : scraper.queue_up) if recur
      STDERR.puts "** #{'WOULD BE ' unless recur}Launching #{what} (handler says #{self.class.handler link}) on #{link}"
      scraper
    }
  end

  # Ensure that a given link (or Nokogiri spec or Mechanize node)
  def absolutize link_or_path, attr=:href
    path =
        case link_or_path
          when String
            link_or_path
          when Mechanize::Page::Link
            link_or_path.href
          when Nokogiri::XML::Element
            link_or_path.attribute attr.to_s
          when Nokogiri::XML::Attr
            link_or_path.to_s
          when respond_to?(attr.to_sym)
            link_or_path.send attr.to_sym
        end
    path.present? ? URI.join(url, path).to_s : url
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

  def find_by_selector selector, attribute_name=nil
    if s = page.search(selector).first
      found = attribute_name ? s.attributes[attribute_name.to_s] : s.text
      STDERR.puts "!! ...found in #{selector}: '#{found}'"
      found.to_s
    end
  end

  # Given a name (or the tag thereof), ensure the existence of:
  # -- a tag of the tagtype
  # -- a referent "defining" that kind of entity
  # -- a reference to the page for such a definition
  # -- optionally, a picture link for that entity
  def define tag_or_tagname, tagtype, page_link, image_link=nil
    tag = tag_or_tagname.is_a?(Tag) ?
        tag_or_tagname :
        Tag.assert(tag_or_tagname.to_s, tagtype: tagtype)
    STDERR.puts "!! ...found #{tag.typename} link to #{tag.name} (Tag ##{tag.id}) at #{absolutize page_link}"
    # Asserting the reference ensures a referent for the tag # Referent.express(tag) if tag.referents.empty?
    Reference.assert absolutize(page_link), tag, :Definition
    if image_link
      irf = Reference.assert absolutize(image_link), tag, :Image
      tag.referents.each { |rft|
        unless rft.picture
          rft.picture = irf
          rft.save
        end
      }
    end
    tag
  end

  # Ensure that a recipe has been filed, and launch it for scraping if new
  def propose_recipe recipe_link, extractions, scraper=nil
    launch recipe_link, scraper unless RecipeReference.where(url: absolutize(recipe_link)).exists?
    recipe = CollectibleServices.find_or_create( { url: absolutize(recipe_link) }, extractions, Recipe)
    recipe.decorate.findings = FinderServices.findings(extractions) if extractions
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
        :recipes_atoz_page
      when /\A\/food\/chefs\/\w+\z/
        :chef_page
      when /\A\/food\/recipes\/search\?.*chefs(\[[^\]]*\]=|\/)([^&]*)/
        :chef_recipes_page
      when /\A\/food\/recipes\/\w+\z/
        :bbc_recipe_page
      when /\A\/food\/ingredients\/by\/letter\z/
        :ingredient_letters
      when /\A\/food\/ingredients\/by\/letter\/[a-z]\z/
        :ingredients_by_letter
      when /\A\/food\/seasons\z/
        :bbc_seasons_page
      when /\A\/food\/\w+\z/
        uri.fragment == 'related-foods' ? :related_ingredients : :ingredient_page
      when /\A\/food\/seasons\/\w+\z/
        :bbc_season_page
    end
  end

  ########## Recipes, by chef #####################
  def chefs # Top level of chef scraping
    launch page.links_with(href: /\/by\/letters\//), :recipes_atoz_page
  end

  def recipes_atoz_page
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

    if s = page.search('h1.fn').first
      tag = define s.content, 'Author', url
      if item = page.search('div#overview p').first
        description = item.text.strip
        tag.referents.each { |ref|
          unless ref.description.present?
            ref.description = description
            ref.save
          end
        }
      end
    end

  end

  def chef_recipes_page
    # The id of the chef is embedded in the query
    unless m = url.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
      errors.add :url, 'doesn\'t match the format of a chefs page'
      return
    end

    chef_id = m[2].to_s

    atag =
        if authlink = page.search('div#queryBox a').first
          define authlink.content, :Author, authlink
        end
    extractions = {'Author Name' => (atag.name if atag) }.compact

    links = page.links_with(href: /\A\/food\/recipes\/[-\w]+\z/)
    links.each { |link|
      STDERR.puts "!!! Identified recipe '#{link.to_s}'"
      propose_recipe link, extractions.merge( 'Title' => link.to_s ), :bbc_recipe_page
    }
    launch page.links.detect { |link| link.rel?('next') }, :chef_recipes_page
  end

  def bbc_recipe_page
    # e.g., http://www.bbc.co.uk/food/recipes/lemon_and_ricotta_tart_44080
    if uri
      # Glean title, description and image
      extractions = HashWithIndifferentAccess.new(
          :Title => find_by_selector("meta[property='og:title']", :content),
          :Description => find_by_selector("meta[property='og:description']", :content),
          :Image => find_by_selector("meta[property='og:image']", :content)
      )

      chef_id = data[:chef_id]
      if link = page.link_with(dom_class: 'chef__link')
        chef_id ||=
            if m = link.href.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
              m[2].to_s
            end
        extractions['Author Name'] = define(link.to_s, 'Author', link.href).name
      end

      # Glean ingredient links from the page, meanwhile ensuring the tag is defined
      extractions[:Ingredients] = page.links_with(dom_class: 'recipe-ingredients__link').collect { |link|
        define(link.to_s, 'Ingredient', link.href).name
      }.join ', '

      r = propose_recipe url, extractions.compact
      # Apply the findings, in case the recipe already existed
      r.decorate.findings = FinderServices.findings extractions

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
    # e.g., http://www.bbc.co.uk/food/ingredients/by/letter/c
    ingredient_links = find_by_selector('li.resource.food a', :href)
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
    # e.g., http://www.bbc.co.uk/food/candied_peel
    unless tagname = data[:ingredient]
      if link = page.links_with(href: /\/food\/recipes\/search\b.*\bkeywords=/).first
        tagname = link.href.sub /\/food\/recipes\/search\b.*\bkeywords=([\w\s]*)/, '\1'
      end
    end
    STDERR.puts "...identified tag '#{tagname}'..."
    tag = Tag.assert tagname, tagtype: 'Ingredient'
    if img = find_by_selector('img#food-image', :src)
      Referent.express(tag) if tag.referents.empty?
      tag.referents.each { |tr|
        unless tr.picture
          tr.picurl = img
          tr.save
          tr.picture.bkg_enqueue
        end
      }
    else
      STDERR.puts "??!? No image found for tag ##{tag.id} (#{tagname})."
    end
  end

  def related_ingredients

  end

  def bbc_seasons_page
    page.search('a.season-image').each { |season_link|
      tag_name = season_link.css('span.season-name').text
      page_link = absolutize season_link.attribute('href').to_s
      img_link = season_link.css('img').attribute('src').to_s
      STDERR.puts "Found '#{tag_name}' -> #{page_link} and image link #{img_link}"
      tag = Tag.assert tag_name, tagtype: 'Occasion'
      Referent.express(tag) if tag.referents.empty?
      dr = Reference.assert page_link, tag, :Definition

      tag.referents.each { |tr|
        unless tr.picture
          tr.picurl = img_link
          tr.save
          tr.picture.bkg_enqueue
        end
      }
    }
  end

  def bbc_season_page
    month_name = page.search('div#column-1 h1').text.sub /.*\s(\w*\z)/, '\1'
    month_tag = define month_name, :Occasion, url
    page.search('ul.resources h4 a').collect { |recipe_link|
      extractions = { 'Title' => recipe_link.text.strip }
      recipe = propose_recipe recipe_link, extractions, :bbc_recipe_page
      STDERR.puts "Found #{month_tag.name} recipe '#{recipe.title}' at #{recipe.url}"
      TaggingServices.new(recipe).assert month_tag, User.super_id
    }
    page.search('div#related-ingredients li a').each { |page_link|
      ingred_tag = define page_link.text.downcase, :Ingredient, page_link
      month_tag.referents.each { |tr|
        tr.ingredient_referents = (tr.ingredient_referents + ingred_tag.referents).uniq
      }
    }
  end
end
