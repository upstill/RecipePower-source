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

  def handler
    subclass.constantize.handler url
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
  def launch link_or_links, what = nil, data=self.data
    if what.is_a? Hash
      what, data = nil, what
    end
    [link_or_links].flatten.compact.collect { |link|
      link = absolutize link # A Mechanize object for a link
      scraper = Scraper.assert link, what, recur, data
      (data[:immediate] ? scraper.perform : scraper.queue_up) if recur
      STDERR.puts "** #{'WOULD BE ' unless recur}Launching #{scraper.what} on #{link}"
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
  def propose_recipe recipe_link, extractions
    launch recipe_link
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
      when /\A\/food\/recipes\/search\?.*occasions(\[[^\]]*\]=|\/)([^&]*)/
        :bbc_occasion_recipes_page
      when /\A\/food\/recipes\/search\?.*programmes(\[[^\]]*\]=|\/)([^&]*)/
        :bbc_programme_recipes_page
      when /\A\/food\/recipes\/[-\w]+\z/
        :bbc_recipe_page
      when /\A\/food\/ingredients\/by\/letter\z/
        :ingredient_letters
      when /\A\/food\/ingredients\/by\/letter\/[a-z]\z/
        :ingredients_by_letter
      when /\A\/food\/seasons\z/
        :bbc_seasons_page
      when /\A\/food\/occasions\z/
        :bbc_occasions_page
      when /\A\/food\/cuisines\z/
        :bbc_genres_page
      when /\A\/food\/[-\w]+\z/
        uri.fragment == 'related-foods' ? :bbc_related_ingredients : :bbc_ingredient_page
      when /\A\/food\/occasions\/[-\w]+\z/
        :bbc_occasion_page
      when /\A\/food\/seasons\/[-\w]+\z/
        :bbc_season_page
      when /\A\/food\/cuisines\/[-\w]+\z/
        :bbc_genre_page
      when /\A\/food\/programmes\/[-\w]+\z/
        :bbc_programme_home_page
    end
  end

  def recipe_item li, extractions_from_context={}
    # Clone the extractions, ensuring that keys are strings
    extractions = {}
    extractions_from_context.each { |key, value| extractions[key.to_s] = value }
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
    rcp = propose_recipe recipe_link, extractions.compact
  end

  def tag_item li, tagtype=nil
    entity_page = absolutize(entity_link = li.search('a').first)
    if img_link = li.search('img').first
      img_link = absolutize img_link, :src
    end
    # How to handle the link depends on what the target page denotes
    # For that, we depend on the #handler method parsing the URL to tell us what kind of link it is
    tagtype ||=
    case self.class.handler(entity_page)
      when :bbc_chefs_atoz_page
      when :bbc_chef_recipes_page
      when :bbc_related_ingredients
      when :bbc_genres_page
      when :bbc_seasons_page
      when :bbc_occasions_page
      when :bbc_recipe_page
      when :bbc_chef_home_page
        :Author
      when :bbc_occasion_page
        :Occasion
      when :bbc_genre_page
        :Genre
      when :bbc_season_page
        :Occasion
      when :bbc_dish_page
        :Dish
      when :bbc_ingredient_page
        :Ingredient
    end
    if tagtype
      launch entity_page, (tagtype == :Dish ? :bbc_dish_page : nil) if recur
      TagServices.define entity_link.text.strip,
                         tagtype: Tag.typenum(tagtype),
                         page_link: entity_page,
                         image_link: img_link
    end
  end

  def accordions extractions={}
    %w{ accordion resource_list filters }.each do |div_class|
      headered_list_items 'h3.accordion-header', 'div.'+div_class do |title, li|
        header_name = title.sub(/^[A-Z]/, &:downcase)
        if block_given?
          yield header_name, li, extractions
        else
          # Assume a recipe, and the header is a role
          if header_name != 'other'
            course_name = header_name.downcase
            TagServices.define course_name, :tagtype => :Course
            course_name
          end
          recipe_item li, extractions.merge('Course' => course_name).compact
        end
      end
    end

  end

  ########## Recipes, by chef #####################
  def chefs # Top level of chef scraping
    launch page.links_with(href: /\/by\/letters\//)
  end

  def bbc_chefs_atoz_page
    chef_ids = page.links_with(href: /\A\/food\/chefs\/[-\w]+\z/).collect { |link|
      link.href.split('/').last
    }.compact
    launch chef_ids.collect { |chef_id|
             'http://www.bbc.co.uk/food/chefs/' + chef_id
           }
    launch chef_ids.collect { |chef_id|
             'http://www.bbc.co.uk/food/recipes/search?chefs[]=' + chef_id
           }
  end

  def bbc_chef_home_page
    unless m = url.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
      errors.add :url, 'doesn\'t match the format of a chefs page'
      return
    end

    if s = page.search('h1.fn').first
      author_name = s.content
      author_tag = TagServices.define( author_name,
                               tagtype: 'Author',
                               page_link: url)
      if item = page.search('div#overview p').first
        description = item.text.strip
        author_tag.referents.each { |ref|
          unless ref.description.present?
            ref.description = description.truncate 250
            ref.save
          end
        }
      end
      # Scrape recipes filed under Dishes accordions
      accordions 'Author Name' => author_name
    end
    headered_list_items 'div.links-module h2', 'ul' do |hdr_title, li|
      if hdr_title == 'Elsewhere on the web'
        TagServices.define author_tag, page_link: 'http://www.bbc.co.uk/nigella' # absolutize(li)
      end
    end
  end

  def bbc_occasion_recipes_page

  end

  def bbc_programme_recipes_page

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
    launch page.links.detect { |link| link.rel?('next') }

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
           }
  end

  def ingredients_by_letter
    # e.g., http://www.bbc.co.uk/food/ingredients/by/letter/o
    Tag.all.pluck(:name).each { |name| STDERR.puts name }
    ingredient_links = page.search('li.resource.food a')
    ingredient_links.each { |link|
      path = link.attribute('href').to_s
      if path.match(/\A\/food\/[-\w]+#related-foods\z/)
        launch link
      else
        img_link = link.search('img').first
        tagname = img_link ? img_link.attribute('alt').to_s : link.text.downcase
        TagServices.define tagname,
                           :tagtype => :Ingredient,
                           :page_link => absolutize(link),
                           :image_link => (absolutize(img_link.attribute('src')) if img_link)
        launch link
      end
    }
  end

  def bbc_ingredient_page
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

  def bbc_related_ingredients

  end

  def bbc_genres_page
    page.search('ol#cuisines li.cuisine a').each { |season_link|
      tag_name = season_link.css('span.cuisine-title').text
      page_link = absolutize season_link.attribute('href').to_s
      if img_link = season_link.css('img').attribute('src')
        img_link = absolutize img_link.to_s
      end
      STDERR.puts "Found '#{tag_name}' -> #{page_link} and image link #{img_link}"
      TagServices.define tag_name,
                               tagtype: 'Genre',
                               page_link: page_link,
                               image_link: img_link
      launch page_link
      launch page_link
    }
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
      launch page_link

      tag.referents.each { |tr|
        unless tr.picture
          tr.picurl = img_link
          tr.save
          tr.picture.bkg_enqueue
        end
      }
    }
  end

  # Process the items of a list that is preceded by a header
  def headered_list_items header_selector, sibling_tag='ul', title=nil, &block
    (page.search(header_selector)).each { |hdr|
      hdr_text = hdr.text.to_s.strip
      hdr.search("~ #{sibling_tag}:first li").each { |li| block.call hdr_text, li } unless title && (title != hdr_text)
    }
  end

  def bbc_dish_page
    dish_name = page.search('div#column-1 h1').text.strip.sub /([-\w]*) recipes/, '\1'
    dish_tag = TagServices.define(dish_name,
                                   :tagtype => :Dish,
                                   :page_link => url)
    accordions 'Dish' => dish_name
    ts = nil
    headered_list_items 'div#related-foods h3', 'ul' do |title, li|
      if title.match /^Varieties of/
        ts ||= TagServices.new(dish_tag)
        ts.make_parent_of tag_item(li, :Dish)
      end
    end

    # A see-also section within a 'links-module' div
    page.search('div.links-module a').each { |see_also_link|
      TagServices.define dish_tag, page_link: absolutize(see_also_link.attribute('href'))
    }

    page.search('a.see-all-search').each { |a| launch a.attribute('href'), :bbc_dish_recipes_page }
  end

  def bbc_genre_page
    genre_name = page.search('div#column-1 h1').text.sub /.*\s([-\w]*\z)/, '\1'
    genre_tag = TagServices.define(genre_name,
                                   :tagtype => :Genre,
                                   :page_link => url)
    accordions 'Genre' => genre_name
    headered_list_items 'div.related-resources-module h2', 'ul', 'Related chefs' do |title, li|
      # The 'Related Chefs' section
      tag = tag_item li
      genre_tag.referents.each { |genre_ref| genre_ref.author_referents |= tag.referents }
    end

    headered_list_items 'div.related-resources-module h3' do |title, li|
      tag = tag_item li, title.singularize.to_sym
      genre_tag.referents.each { |genre_ref|
        case tag.typesym
          when :Author
            genre_ref.author_referents |= tag.referents
          when :Ingredient
            genre_ref.ingredient_referents |= tag.referents
          when :Dish
            genre_ref.dish_referents |= tag.referents
        end
      }
    end

    # A see-also section within a 'links-module' div
    page.search('div.links-module a').each { |see_also_link|
      TagServices.define genre_tag, page_link: absolutize(see_also_link.attribute('href'))
    }
  end

  def bbc_programme_home_page
    # The programme_link is the home page of the program on the BBC
    programme_link = page.search('div#episode-detail a').first
    programme_name = programme_link.text.strip # page.search('title').text.sub(/BBC - Food - Recipes from Programmes :/, '').strip
    programme_description = page.search('div#episode-detail p').first.text.strip
    programme_image = find_by_selector('div#programme-brand img', :src)
    programme_tag = TagServices.define(programme_name,
                                       {
                                           :tagtype => :Source,
                                           :description => programme_description,
                                           :page_link => url,
                                           :image_link => (programme_image if programme_image.present?)
                                       }.compact
    )
    TagServices.define programme_tag, page_link: absolutize(programme_link.attribute('href'))

    headered_list_items 'div.related-resources-module h2', 'ul' do |header_name, li|
      if header_name == 'Related chefs'
        link = li.search('a').first
        img = link.search('img').first
        chef_name = img.attribute('alt').to_s
        chef_img = img.attribute('src').to_s
        chef_link = absolutize link.attribute('href').to_s
        chef_tag = TagServices.define chef_name, {
          tagtype: :Author,
          page_link: chef_link,
          image_link: chef_img
        }.compact
        TagServices.new(programme_tag).suggests chef_tag
      end
    end

    # The seemore link finds all recipes under that programme
    if seemore = page.search('p.see-all a.see-all-search').first
      launch seemore.attribute('href')
    end

  end

  def bbc_season_page
    month_name = page.search('div#column-1 h1').text.sub /.*\s([-\w]*\z)/, '\1'
    month_tag = TagServices.define(month_name,
                                   :tagtype => :Occasion,
                                   :page_link => url)
    accordions 'Occasion' => month_name
=begin
    if seemore = find_by_selector('p.see-more a.see-all-search', :href)
      launch seemore
    end
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

  def bbc_occasions_page
      (page.search('ul.occasions li') + page.search('ul#other-occasions li')).each { |li_elmt|
      if occ_link = li_elmt.search('h4 a').first
        occ_name = occ_link.text.strip
        occ_link = absolutize occ_link.attribute('href')
      end
      (img_link = li_elmt.search('h4 a img').first) && (img_link = img_link.attribute('src'))
      definitions = {
          tagtype: :Occasion,
          page_link: occ_link,
          image_link: absolutize(img_link)
      }.compact
      TagServices.define occ_name.to_s, definitions
      launch occ_link, 'Occasion' => occ_name
    }
  end

  def bbc_occasion_page
    occ_name = data[:Occasion] || find_by_selector( 'h1.bordered').strip
    occ_name.sub! ' recipes', ''
    occ_tag = TagServices.define occ_name, tagtype: Tag.typenum(:Occasion), page_link: url
    if seemore = find_by_selector('p.see-more a.see-all-search', :href)
      launch seemore
    end
    accordions 'Occasion' => occ_name
    if related = page.search('div.related-resources-module').first
      resource_type = related.search('h3').first.text # Ingredients
      related.search('ul li a').each { |ingtag|
        food_link = ingtag.attribute 'href'
        food_name = ingtag.text.strip
        if img_link = ingtag.search('img').first
          img_link = absolutize img_link, :src
        end
        case resource_type
          when /^Ingredients/
            ing_tag = TagServices.define(food_name,
                               :tagtype => :Ingredient,
                               :page_link => absolutize(food_link),
                               :image_link => img_link)
        end
        occ_tag.referents.each { |tr|
          tr.ingredient_referents = tr.ingredient_referents | ing_tag.referents
        }
        launch food_link, Ingredient: food_name
      }
    end
  end
end
