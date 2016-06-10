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
          error = 'Host isn\'t talking at the moment'
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

  # Get the page data via Mechanize
  def page
    return @page if @page

    STDERR.puts "** Getting page #{url}"
    mechanize = Mechanize.new
    mechanize.user_agent_alias = 'Mac Safari'
    mechanize
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

  # Ensure that a recipe has been filed, and launch it for scraping if new
  def propose_recipe recipe_link, extractions, scraper=nil
    launch recipe_link, scraper
    recipe = CollectibleServices.find_or_create({url: absolutize(recipe_link)}, extractions, Recipe)
    STDERR.puts "Defined Recipe at #{absolutize recipe_link}:"
    extractions.each { |key, value| STDERR.puts "        #{key}: '#{value}'" }
    STDERR.puts ''
    recipe.decorate.findings = FinderServices.findings(extractions) if extractions
    recipe
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
        :bbc_chefs_atoz_page
      when /\A\/food\/chefs\/[-\w]+\z/
        :bbc_chef_home_page
      when /\A\/food\/recipes\/search\?.*chefs(\[[^\]]*\]=|\/)([^&]*)/
        :bbc_chef_recipes_page
      when /\A\/food\/recipes\/[-\w]+\z/
        :bbc_recipe_page
      when /\A\/food\/ingredients\/by\/letter\z/
        :ingredient_letters
      when /\A\/food\/ingredients\/by\/letter\/[a-z]\z/
        :ingredients_by_letter
      when /\A\/food\/seasons\z/
        :bbc_seasons_page
      when /\A\/food\/[-\w]+\z/
        uri.fragment == 'related-foods' ? :related_ingredients : :ingredient_page
      when /\A\/food\/seasons\/[-\w]+\z/
        :bbc_season_page
    end
  end

  def recipe_item li, extractions_from_context={}
    extractions = extractions_from_context.clone
    recipe_link = li.search('a').first
    extractions['Title'] = recipe_link.text.strip
    if img_link = li.search('img').first
      extractions['Image'] = absolutize img_link, :src
    end
    if chef_name = li.search('span.chef-name').first
      extractions['Author Name'] = chef_name.text
    end
    li.search('h4').each { |hdr|
      if match = hdr.text.match(/^(By|From|Preparation time:|Cooking time:|Serves)\s*(\w.*)$/)
        key, value = match[1].strip, match[2].strip
        case key.sub(/\s.*/, '')
          when 'By'
            extractions['Author Name'] = value
          when 'From'
            extractions['Source'] = value
          when 'Preparation'
            extractions['Prep Time'] = value
          when 'Cooking'
            extractions['Cooking Time'] = value
          when 'Serves'
            extractions['Yield'] = value.to_s + ' Servings'
        end
      elsif (cl = hdr.attribute('class')) &&
          (cl.text.strip == 'icon') &&
          (link = find_by_selector('a', :href)) &&
          link.match(/\A\/food\/(\w*)\/([-\w]*)\z/)
        extractions[$1.capitalize] = $2
      end
    }
    rcp = propose_recipe recipe_link, extractions.compact, :bbc_recipe_page
  end

  def accordions extractions_from_context={}
    page.search('h3.accordion-header').each { |header|
      extractions = extractions_from_context.clone
      header_name = header.text.sub(/^[A-Z]/, &:downcase)

      if div = header.search('~ div.resource-list').first
        div_class = 'resource-list'
      elsif div = header.search('~ div.filters').first
        div_kind = 'filters'
      end
      div.search('li').each { |li|
        if block_given?
          yield header_name, li, extractions
        else
          # Assume a recipe, and the header is a role
          unless header_name == 'other'
            header_name = header_name.singularize
            TagServices.define header_name, :tagtype => :Course
            extractions['Course'] = header_name
          end
          recipe_item li, extractions
        end
      } if div
    }

  end

  ########## Recipes, by chef #####################
  def chefs # Top level of chef scraping
    launch page.links_with(href: /\/by\/letters\//), :bbc_chefs_atoz_page
  end

  def bbc_chefs_atoz_page
    chef_ids = page.links_with(href: /\A\/food\/chefs\/[-\w]+\z/).collect { |link|
      link.href.split('/').last
    }.compact
    launch chef_ids.collect { |chef_id|
             'http://www.bbc.co.uk/food/chefs/' + chef_id
           }, :bbc_chef_home_page
    launch chef_ids.collect { |chef_id|
             'http://www.bbc.co.uk/food/recipes/search?chefs[]=' + chef_id
           }, :bbc_chef_recipes_page
  end

  def bbc_chef_home_page
    unless m = url.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
      errors.add :url, 'doesn\'t match the format of a chefs page'
      return
    end

    if s = page.search('h1.fn').first
      author_name = s.content
      tag = TagServices.define( author_name,
                               tagtype: 'Author',
                               page_link: url)
      if item = page.search('div#overview p').first
        description = item.text.strip
        tag.referents.each { |ref|
          unless ref.description.present?
            ref.description = description
            ref.save
          end
        }
      end
      # Scrape recipes filed under Dishes accordions
      accordions 'Author Name' => author_name
    end
  end

  def bbc_chef_recipes_page
    # The id of the chef is embedded in the query
    unless m = url.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
      errors.add :url, 'doesn\'t match the format of a chefs page'
      return
    end

    chef_id = m[2].to_s

    atag =
        if authlink = page.search('div#queryBox a').first
          TagServices.define(authlink.content,
                             :tagtype => :Author,
                             :page_link => absolutize(authlink))
        end
    extractions = { 'Author Name' => (atag.name if atag) }
    page.search('div#article-list li').each { |li|
      recipe_item li, extractions
    }
    launch page.links.detect { |link| link.rel?('next') }, :chef_recipes_page

    accordions extractions do |header_name, li, extractions|
      if link = li.search('a').first
        tagtype =
        case header_name
          when 'dishes'
            :Dish
          when 'courses'
            :Course
          when 'occasions'
            :Occasion
          when 'chefs'
            :Author
          when 'programmes'
            :Source
          when 'special diets'
            :Diet
          when 'cuisines'
            :Genre
        end
        tagname = li.text.sub(/^\s*Show\s*/,'').sub(/\s*\(\d*\).*$/,'')
        tagname.downcase! if tagtype == :Dish
        TagServices.define tagname, :tagtype => Tag.typenum(tagtype) if tagtype
      end
    end
  end

  def bbc_recipe_page
    # e.g., http://www.bbc.co.uk/food/recipes/lemon_and_ricotta_tart_44080
    if uri
      # Glean title, description and image
      extractions = HashWithIndifferentAccess.new(
          :Title => find_by_selector("meta[property='og:title']", :content),
          :Description => find_by_selector("meta[property='og:description']", :content),
          'Prep Time' => find_by_selector("p.recipe-metadata__prep-time"),
          'Cooking Time' => find_by_selector("p.recipe-metadata__cook-time"),
          'Yield' => find_by_selector('p.recipe-metadata__serving'),
          :Image => find_by_selector("meta[property='og:image']", :content)
      )
      if (diet = find_by_selector('div.recipe-metadata__dietary a p')).present?
        extractions['Diet'] = diet.strip
      end

      chef_id = data[:chef_id]
      if link = page.link_with(dom_class: 'chef__link')
        chef_id ||=
            if m = link.href.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
              m[2].to_s
            end
        extractions['Author Name'] = TagServices.define(link.to_s,
                                                        tagtype: 'Author',
                                                        page_link: absolutize(link.href)).name
      end

      # Glean ingredient links from the page, meanwhile ensuring the tag is defined
      extractions[:Ingredients] = page.links_with(dom_class: 'recipe-ingredients__link').collect { |link|
        TagServices.define(link.to_s,
                           tagtype: 'Ingredient',
                           page_link: absolutize(link.href)).name
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
    # e.g., http://www.bbc.co.uk/food/ingredients/by/letter/o
    Tag.all.pluck(:name).each { |name| STDERR.puts name }
    ingredient_links = page.search('li.resource.food a')
    ingredient_links.each { |link|
      path = link.attribute('href').to_s
      if path.match(/\A\/food\/[-\w]+#related-foods\z/)
        launch link, :related_ingredients
      else
        img_link = link.search('img').first
        tagname = img_link ? img_link.attribute('alt').to_s : link.text.downcase
        TagServices.define tagname,
                           :tagtype => :Ingredient,
                           :page_link => absolutize(link),
                           :image_link => (absolutize(img_link.attribute('src')) if img_link)
        launch link, :ingredient_page
      end
    }
  end

  def ingredient_page
    # e.g., http://www.bbc.co.uk/food/candied_peel
    unless tagname = data[:ingredient]
      if link = page.links_with(href: /\/food\/recipes\/search\b.*\bkeywords=/).first
        tagname = link.href.sub /\/food\/recipes\/search\b.*\bkeywords=([-\w\s]*)/, '\1'
      end
    end
    STDERR.puts "...identified tag '#{tagname}' for #{url}"
    ingredient_tag = TagServices.define(tagname,
                                        :tagtype => :Ingredient,
                                        :page_link => url,
                                        :image_link => absolutize(find_by_selector('img#food-image', :src)))

    # scrape the related-foods section
    page.search('div#related-foods h3').each { |related_section|
      list = related_section.search('~ ul').first
      resources = list.search('li a').each { |related_link|
        definition_link = related_link.attribute 'href'
        definition_name = related_link.text.strip
        if img_link = related_link.search('img').first
          img_link = absolutize img_link, :src
        end
        case related_section.text.strip
          when /^Varieties/
            TagServices.define(definition_name,
                               :tagtype => :Ingredient,
                               :page_link => absolutize(definition_link),
                               :image_link => img_link,
                               :kind_of => ingredient_tag)
          when /^Typically made with/
            TagServices.define(definition_name,
                               :tagtype => :Dish,
                               :page_link => absolutize(definition_link),
                               :image_link => img_link,
                               :suggested_by => ingredient_tag)
        end
      }
    }

    accordions 'Ingredients' => tagname
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
      launch page_link, :bbc_season_page

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
    month_name = page.search('div#column-1 h1').text.sub /.*\s([-\w]*\z)/, '\1'
    month_tag = TagServices.define(month_name,
                                   :tagtype => :Occasion,
                                   :page_link => url)
    accordions 'Occasion' => month_name

=begin
    page.search('ul.resources h4 a').collect { |recipe_link|
      extractions = {'Title' => recipe_link.text.strip}
      recipe = propose_recipe recipe_link, extractions, :bbc_recipe_page
      STDERR.puts "Found #{month_tag.name} recipe '#{recipe.title}' at #{recipe.url}"
      TaggingServices.new(recipe).assert month_tag, User.super_id
    }
=end
    page.search('div#related-ingredients li a').each { |page_link|
      ingred_tag = TagServices.define( page_link.text.downcase,
                                      :tagtype => :Ingredient,
                                      :page_link => absolutize(page_link))
      month_tag.referents.each { |tr|
        tr.ingredient_referents = (tr.ingredient_referents + ingred_tag.referents).uniq
      }
    }
  end
end
