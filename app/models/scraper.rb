# The Registrar class registers scraping findings with the database
class Registrar < Object

  attr_accessor :url

  # Initialize the Registrar for a particular url
  def initialize url
    @url = url.to_s
  end

  # Ensure that a given link (or Nokogiri spec or Mechanize node) has a valid url
  def absolutize link_or_path, attr=:href
    path =
        case link_or_path
          when String
            link_or_path
          when Mechanize::Page::Link
            link_or_path.href
          when Nokogiri::XML::Element
            link_or_path.attribute(attr.to_s).to_s
          when Nokogiri::XML::Attr
            link_or_path.to_s
          when respond_to?(attr.to_sym)
            link_or_path.send attr.to_sym
          when nil
            return nil
        end
    path.present? ? URI.decode(safe_uri_join(url, path).to_s) : url
  end

  # Ensure that a recipe has been filed, and launch it for scraping if new
  def register_recipe link_or_page, extractions={}
    recipe_link =
    if link_or_page.is_a?(Mechanize::Page)
      found = link_or_page.search 'title'
      extractions.merge!('Title': found.first.text) if found
      link_or_page.uri.to_s
    else
      link_or_page
    end
    recipe = CollectibleServices.find_or_create({url: absolutize(recipe_link)}, extractions, Recipe)
    Rails.logger.info "!!!Scraper Defined Recipe at #{absolutize recipe_link}:"
    extractions.each { |key, value| Rails.logger.info "!!!Scraper Defined Recipe        #{key}: '#{value}'" }
    Rails.logger.info ''
    recipe.decorate.findings = FinderServices.from_extractions extractions
    recipe
  end

  # Commit the link in association with a tag
=begin
  def self.register_link_for_tag tagname, link, ts_options
    link = absolutize link
    if Rails.development?
      puts "#{link} gets linked to tag #{tagname}"
      ts_options.each { |name, val| puts "    #{name} => #{val}" }
    else
      TagServices.define tagname, ts_options.merge(page_link: link)
    end
  end

=end
  # Associate a name with a tag, or add a page_link to an existing tag
  # name_or_tag: a string or a Tag instance;
  #     tagtype required to give the tag type if a string
  #     tagtype omitted if already a tag
  # page_link (optional): a page to associate with the tag
  # options: other info useful to TagServices.define
  #   :page_kind: how the PageRef will be classified
  #   :image_link: for an image to be associated with the reference
  #   :link_text: passed to the page_ref for labeling its URL in links
  #   :description: description of the associated referent
  #   :parent_tag: tag to be a parent of the asserted tag
  #   :child_tag: tag to be a child of the asserted tag
  #   :suggests: tag to be suggested by the asserted tag
  #   :suggested_by: tag that will suggest the asserted tag
  def register_tag name_or_tag, tagtype=nil, page_link=nil, options={}
    if name_or_tag.is_a?(Tag)
      page_link, options = tagtype, page_link
    else
      options[:tagtype] = tagtype
    end
    if page_link.is_a?(Hash)
      options, page_link = page_link, nil
    end
    options[:page_link] = absolutize page_link
    options[:image_link] = absolutize options[:image_link]
    parent_tag = options.delete :parent_tag
    child_tag = options.delete :child_tag
    suggested_tag = options.delete :suggests
    suggested_by = options.delete :suggested_by
    tag = TagServices.define name_or_tag, options.compact
    TagServices.new(parent_tag).make_parent_of tag if parent_tag
    TagServices.new(tag).make_parent_of child_tag if child_tag
    TagServices.new(tag).suggests suggested_tag if suggested_tag
    TagServices.new(suggested_by).suggests tag if suggested_by
    tag
  end

  # Register a product
  # tag_or_referent: the key whose referent will be associated with the product
  # page_link: URL for the product page
  # options:
  #    :title may be different from the name of the tag
  def register_product tag_or_referent, page_link, options={}
    if tag_or_referent.is_a?(Tag)
      tag, ref = tag_or_referent, Referent.express(tag_or_referent)
    else
      ref, tag = tag_or_referent, tag_or_referent.primary_expression
    end
    product_pageref = PageRefServices.assert :product, page_link.to_s
    product_pageref.save
    title = (options[:title] && options[:title].to_s) || product_pageref.title.if_present || tag.name
    unless product = ref.products.where(page_ref_id: product_pageref.id).first
      product = Product.find_or_create_by(page_ref: product_pageref, title: title)
      ref.products << product
      ref.save
    end
    # This product may also represent an offering
    if options[:as_offering]
      unless offering = product.offerings.where(page_ref_id: product_pageref.id).first
        offering = Offering.find_or_create_by(page_ref: product_pageref)
        product.offerings << offering
        product.save
      end
    end
    product
  end

  # Assert a list into the database with the given name. Options:
  # :owner is the User who owns it
  # :picurl is the list's picture
  # :description is the list's description
  def register_list name, options={}
    list = List.assert name, options[:owner] || User.superuser
    list.picurl = absolutize options[:picurl] if options[:picurl]
    list.description = options[:description].strip if options[:description].present?
    list.save
    list
  end

  def add_to_list item, list, options={}
    ListServices.new(list).include item, (options[:user] || User.superuser)
  end
end

# The scraper class exists to scrape pages: one per scraper. The scraper either:
# 1) generates more scrapers based on the contents of the page, or
# 2) finds data and adds that to the RecipePower database
# Attributes:
# url: the url of the page to be examined
# site: the site being examined, expressed as the name of a method of the scraper model
# what: the contents that are being sought (a section of the method that scrapes this kind of page)
class Scraper < ActiveRecord::Base
  include Backgroundable
  backgroundable

  attr_accessible :url, :what, :subclass, :run_at, :waittime, :errcode, :recur
  attr_accessor :immediate, :page

  attr_accessor :mechanize
  # @@LaunchedScrapers = {}

  after_create { |sc|
    sc.bkg_launch sc.recur # Launch iff necessary
  }

  def self.clear_all
    Scraper.delete_all
    # @@LaunchedScrapers = {}
  end

  # Assert a scraper by url
  # what: if given, it forces the class of scraper
  #       if not given, the scraper class is inferred from the url host
  # recur: persistent flag indicating whether, in the course of scraping, new scrapers should be spawned as found
  def self.assert url, what=nil, recur=true
    unless what.is_a?(String) || what.is_a?(Symbol)
      what, recur = nil, what
    end

    uri = normalized_uri CGI.unescape(url)
    subclass = (uri.host.capitalize.split('.') << 'Scraper').join('_')

    # Each subclass has a #handler method to map from the uri to the method used to parse that url
    what ||= subclass.constantize.handler uri

    scraper = self.create_with(recur: recur).find_or_initialize_by(url: uri.to_s, what: what, subclass: subclass)
    Rails.logger.info "!!!#{scraper.persisted? ? 'Scraper Already' : 'New Scraper'} Defined for '#{scraper.what}' on #{uri} (status #{scraper.status})"
    scraper.bkg_launch
    scraper
  end

  def ping
    page.search('title').present?
  end

  # perform with error catching
  def perform 
    self.errcode = 0
    Rails.logger.info "!!!Scraper Started Performing #{what} on #{url} with status #{status}"
    # Make the connection and get the page
    handler = self.becomes subclass.constantize
    handler.open
    # Run the scraper method for this page
    handler.send what.to_sym # Invoke the scraper
    Rails.logger.info "!!!Scraper Finished Performing #{what} on #{url} with status #{status}"
  end

  def registrar
    @registrar = Registrar.new page.uri
  end

  # Handle performance errors
  # This is the place for Backgroundables to record any persistent error state beyond :good or :bad status,
  # because, by default, that's all that's left after saving the record
  # Here, we record an errcode as well as adding the error to :base errors
  def error job, exception
    self.errmsg = "#{exception.class.to_s} ERROR: #{exception.to_s}"
    if exception.respond_to?(:response_code)
      elaboration =
      case errcode = exception.response_code.to_i
      when 503
        ' Host isn\'t talking at the moment'
      when 404
        ' URL doesn\'t point to anything!'
      end
      self.errmsg << "(HTTP Response Code #{errcode}#{elaboration})"
    else
      self.errcode = -1
    end
    cutoff = exception.backtrace.find_index { |lev| lev.match('scraper.rb') && lev.match('perform') } || -1
    self.errmsg << "\n\t" + exception.backtrace[0..cutoff].join("\n\t")
    # Adding an error here ensures that the object will be recorded as :bad
    Rails.logger.info "!!!Scraper ##{id} Failed on #{url} with status #{status}:\n#{errmsg}"
    errors.add :base, "Error ##{errcode} (#{errmsg})"
  end

  def handler
    subclass.constantize.handler url
  end

  protected

  # Define a scraper to follow a link or links and return it, for whatever purpose
  def scrape link_or_links, what = nil
    unless what.is_a?(String) || what.is_a?(Symbol)
      what, imm = nil, what
    end
    [link_or_links].flatten.compact.collect { |link|
      link = registrar.absolutize link # A Mechanize object for a link
      Scraper.assert link, what, recur
    }
  end

  # Open the page for reading via Mechanize
  def open
    Rails.logger.info "!!!Scraper Getting page #{url}"
    mechanize = Mechanize.new
    mechanize.user_agent_alias = 'Mac Safari'
    mechanize
    self.page = mechanize.get url
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
      found.to_s
    end
  end

end

class Oaktownspiceshop_com_Scraper < Scraper
  def self.handler url_or_uri
    uri = url_or_uri.is_a?(String) ? URI(url_or_uri) : url_or_uri
    case uri.path
    when /\/blogs\/recipes$/
      :oss_recipes
    when /\/blogs\/recipes\//
      :oss_recipe
    when /\/products\//
      :oss_product
    end
  end

  def oss_product

  end

  def oss_recipes
    page.search( 'div.article h2 a').each do |link|
      # For each recipe listed on the page
      url = link.attribute('href')
      registrar.register_recipe url, Title: link.text
      scrape url
    end
    if next_link = page.search('span.next a').first
      scrape next_link
    end
  end

  def oss_recipe
    # Get the links that are embedded in the ingredient list
    # Each of these is to a Product: href => link, title =>
    # The text of the link is a more-generic tag
    # We ensure that:
    # -- there's such a Tag, and it has a Referent
    # -- the Tag gets applied to the Recipe
    # -- the referent gets an associated Product (linked to the Product page)
    # -- the Product gets an Offering, also linked to the page
    recipe = registrar.register_recipe page
    product_links = page.search 'div.clearfix.section a[href*="/products/"]'
    ts = TaggingServices.new recipe
    product_links.collect do |link|
      # Ensure there's a tag with an associated Referent
      tag = registrar.register_tag link.text, :Ingredient
      registrar.register_product tag, link.attribute('href'), title: link.attribute('title'), as_offering: true
      ts.tag_with tag, User.super_id
    end
  end
end

# Scraper for SeriousEats
class Www_seriouseats_com_Scraper < Scraper
  def self.handler url_or_uri
    :se_tag_page
  end

  def se_tag_page
    next_links = page.search ('footer.block__footer > div.more > a.btn-tertiary')
    next_links.each { |link|
      if link.text.match 'next'
        scrape link, :se_tag_page
        break
      end
    }
    recipe_links = page.search 'div.module > div.module__wrapper a.module__link'
    category_links = page.search 'a.category_link'
    category_links.each { |link|
      registrar.register_tag tagname, :Ingredient, link, :page_kind => :about
      # self.register_link_for_tag tagname,
      #                            link,
      #                            :tagtype => :Ingredient,
      #                            :page_kind => :about
    }
  end

  def se_category_page
  end

end

class En_wikibooks_org_Scraper < Scraper

  def self.handler url_or_uri
    :wikipedia_cookbook_ingredients
  end

  def wikipedia_cookbook_ingredients
    next_links = page.search('div#mw-pages > a')
    next_links.each { |link|
      if link.text.match 'next'
        scrape link
        break
      end
    }
    ingredient_links = page.search('div.mw-category-group > ul > li > a')
    tagnames =
    ingredient_links.collect { |link|
      title = link.text
      tagname = title.sub(/^Cookbook:/, '').gsub(/_/,' ').downcase
      puts "Tag #{tagname} getting associated with #{link}"
      next unless title.match(/^Cookbook:/) && (URI::decode(link[:href]) == link[:href]) # Easy way to check for diacriticals
      url = absolutize link
      # TagServices.define tagname,
      #                    :tagtype => :Ingredient,
      #                    :page_link => url,
      #                    :page_kind => :about
      registrar.register_tag tagname, :Ingredient, url, :page_kind => :about
      tagname
    }.compact
    puts "#{tagnames.count} pages pegged: "
    puts tagnames
  end


end

class Www_bbc_co_uk_Scraper < Scraper

  # Predict what handler will scrape the page
  def self.handler url_or_uri
    uri = url_or_uri.is_a?(String) ? (normalized_uri CGI.unescape(url_or_uri)) : url_or_uri
    case URI.decode [uri.path.sub(/\/$/,''), uri.query].compact.join('?')
      when /\A\/food\z/
        :bbc_food_page
      when /\A\/food\/(chefs|dishes)\/by\/letter(s)?\//
        :"bbc_#{$1}_atoz_page"
      when /\A\/food\/(dishes|chefs|recipes|seasons|techniques|occasions|cuisines|ingredients|programmes)\z/
        "bbc_#{$1}_page".to_sym
       when /\A\/food\/(courses|occasions|techniques|seasons|cuisines|programmes|collections|diets|chefs|recipes)\/[-\w]+\z/
        "bbc_#{$1.singularize}_home_page".to_sym
      when /\A\/food\/recipes\/search\?.*(dishes|occasions|chefs|programmes|courses|diets|cuisines|keywords)((\[[^\]]*\])?=|\/)([^&]*)/
        "bbc_#{$1.singularize}_recipes_page".to_sym
      when /\A\/food\/ingredients\/by\/letter\/[a-z]\z/
        :bbc_ingredients_by_letter
      when /\A\/food\/[-\w]+\z/
        :bbc_food_home_page
      else
        x=2
    end
  end

  def recipe_item li, extractions_from_context={}
    # Clone the extractions, ensuring that keys are strings
    extractions = {}
    extractions_from_context.each { |key, value| extractions[key.to_s] = value }
    recipe_link = li.search('a').first
    return unless recipe_link['href'].match /food\/recipes\//
    extractions['Title'] = recipe_link.text.strip
    if img_link = li.search('img').first
      extractions['Image'] = registrar.absolutize img_link, :src
    end
    if chef_name = li.search('span.chef-name').first
      extractions['Author'] = chef_name.text
    end
    li.search('h4').each { |hdr|
      if match = hdr.text.match(/^(By|From|Preparation time:|Cooking time:|Serves)\s*(\w.*)$/)
        key, value = match[1].strip, match[2].strip
        case key.sub(/\s.*/, '')
          when 'By'
            extractions['Author'] = value
          when 'From'
            extractions['Source'] = value
          when 'Preparation'
            extractions['Prep Time'] = value
          when 'Cooking'
            extractions['Cooking Time'] = value
          when 'Serves'
            extractions['Yield'] = labelled_quantity value.to_i, 'Serving', ''
        end
      elsif (cl = hdr.attribute('class')) && (cl.text.strip == 'icon')
        if (link = hdr.search('a').first) && link['href'].to_s.match(/\A\/food\/(\w*)\/([-\w]*)\z/)
          bbc_type, name = $1, $2
          rp_type = case bbc_type
                      when 'seasons'
                        name.capitalize!
                        'Occasion'
                      else
                        bbc_type.capitalize.singularize
                    end
          if extractions[rp_type].present?
            extractions[rp_type.pluralize] = "#{extractions.delete rp_type}, #{name}"
          else
            extractions[rp_type] = name
          end
        else
          if hdr.search('span.quick-and-easy').first
            # Icon denoting 'quick and easy recipes'
            extractions['Total Time'] = 'Under a half hour'
          end
        end
      end
    }
    registrar.register_recipe recipe_link, extractions.compact
    scrape recipe_link
  end

  # Scrape the definition of a tag, and the link to the tag's page
  def tag_item li, tagtype=nil
    entity_link = li.search('a').first
    scrape entity_link if recur
    tagname = entity_link.text.strip
    if tagtype
      # Dishes and ingredients are downcased
      tagname = tagname.downcase if (tagtype == :Dish || tagtype == :Ingredient)
    else
      tagtype =
          # How to tag the link depends on what the target page denotes
          # For that, we depend on the #handler method parsing the URL to tell us what kind of link it is
          case self.class.handler(entity_link)
            when :bbc_chef_home_page
              :Author
            when :bbc_occasion_home_page
              :Occasion
            when :bbc_cuisine_home_page
              :Genre
            when :bbc_season_home_page
              :Occasion
          end
    end
    # if img_link = li.search('img').first
    #   img_link = absolutize img_link, :src
    # end
    # These are home pages, so they'll just be given the name of the tag
    # TagServices.define(tagname,
    #                    tagtype: Tag.typenum(tagtype),
    #                    page_link: absolutize(entity_link),
    #                    image_link: img_link) if tagtype
    registrar.register_tag(tagname, tagtype, entity_link, image_link: li.search('img').first) if tagtype
  end

  def accordions enclosure_selector=nil, extractions={}
    if enclosure_selector.is_a? Hash
      enclosure_selector, extractions = nil, enclosure_selector
    end
    %w{ .accordion .resource_list #dishes-filters }.each do |div_class|
      headered_list_items "#{enclosure_selector} h3.accordion-header", 'div'+div_class do |title, li|
        header_name = title.sub(/^[A-Z]/, &:downcase)
        if block_given?
          yield header_name, li, extractions
        else
          # Assume a recipe, and the header is a role
          if header_name == 'other'
            course_name = nil
          else
            course_name = header_name.downcase
            # TagServices.define course_name, :tagtype => :Course
            registrar.register_tag course_name, :Course
            course_name
          end
          recipe_item li, extractions.merge('Course' => course_name).compact
        end
      end
    end

  end

  # The BBC Food home page lists special diets
  def bbc_food_page
    headered_list_items 'dt#special-diets', 'dd' do |header_text, li|
      if diet_atag = li.search('a').first
        diet_name = diet_atag.text.strip.sub(/\s*recipes$/, '').sub ' ', '-'
        # diet_url = absolutize diet_atag.attribute('href')
        # TagServices.define diet_name.downcase,
        #                    :tagtype => :Diet,
        #                    :page_link => diet_url
        registrar.register_tag diet_name.downcase, :Diet, diet_atag
        scrape diet_atag
      end
    end
    page.search('ol#site-nav a').each do |link|
      link.attribute('href').to_s.match /.*\/food\/(\w*)\b/
      if (topic = $1).present?
        scrape link unless %w{ my about ingredients }.include? topic
      end
    end
  end

  ########## Recipes, by chef #####################
  def bbc_chefs_page # Top level of chef scraping
    scrape page.links_with(href: /\/by\/letters\//)
  end

  def bbc_dishes_page # Top level of dish scraping
    scrape page.links_with(href: /\/by\/letter\//)
  end

  def bbc_chefs_atoz_page
    chef_ids = page.links_with(href: /\A\/food\/chefs\/[-\w]+\z/).collect { |link|
      link.href.split('/').last
    }.compact
    scrape chef_ids.collect { |chef_id|
             'http://www.bbc.co.uk/food/chefs/' + chef_id
           }
    scrape chef_ids.collect { |chef_id|
             'http://www.bbc.co.uk/food/recipes/search?chefs[]=' + chef_id
           }
  end

  def bbc_dishes_atoz_page
    dish_ids = page.search('li.resource.food a').collect { |a|
      a.attribute('href').to_s.sub /\/food\/(\w*)\b.*$/, '\1'
    }.compact.uniq
    scrape dish_ids.collect { |dish_id|
             'http://www.bbc.co.uk/food/' + dish_id
           }
    scrape dish_ids.collect { |dish_id|
             'http://www.bbc.co.uk/food/recipes/search?dishes[]=' + dish_id
           }
  end

  def bbc_chef_home_page
    unless m = url.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
      errors.add :url, 'doesn\'t match the format of a chefs page'
      return
    end

    if s = page.search('h1.fn').first
      author_name = s.content
      # author_tag = TagServices.define( author_name,
      #                          tagtype: 'Author',
      #                          page_link: url)
      author_tag = registrar.register_tag author_name, :Author, url
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
      accordions 'Author' => author_name
    end
    headered_list_items 'div.links-module h2', 'ul' do |hdr_title, li|
      if hdr_title.match( 'Elsewhere') && (link = li.search('a').first)
        # TagServices.define author_tag, page_link: absolutize(link), link_text: link.content
        registrar.register_tag author_tag, link, link_text: link.content
      end
    end
  end

  def tidy_name name, typesym
    name.downcase! if [:Dish, :Course, :Diet].include?(typesym)
    name.strip.sub /\b\s*recipes$/, ''
  end

  def tag_def_label result_type, typesym, tagname
    label = ApplicationController.helpers.t("definition_reference.label.tag.#{typesym}", entity_type: result_type.downcase.pluralize, tagname: tagname)
    label[0] = label[0].upcase
    label
  end

  # How to process a recipes page due to a search on a tag (after determining the type of tag)
  def bbc_tag_recipes_page tagtype
    tag = nil
    typesym = Tag.typesym tagtype
    if taghead = page.search('div#column-1 h2').first
      tagname = taghead.content
      tagname.downcase! if [:Dish, :Course, :Diet].include?(typesym)
      tagname.sub! /\s*\.\s*$/, ''
      case typesym
        when :Ingredient
          tagname.sub! /^.*ecipes with keyword:?/i, ''
        when :Course
          tagname.sub! /^.*ecipes by course:?/i, ''
        when :Source
          tagname.sub! /^.*ecipes from/i, ''
        when :Author
          tagname.sub! /^.*ecipes by/i, ''
        when :Occasion, :Dish, :Diet, :Genre
          tagname.sub! /\brecipes\s*(and menus)?\s*$/i, ''
      end
      tagname.strip!
      unless url.match /page=/
        link_text = taghead.content.sub(/\.\s*$/, '').strip.gsub(/\s+/, ' ')
        # tag = TagServices.define tagname,
        #                          tagtype: typesym,
        #                          page_link: url,
        #                          link_text: link_text
        tag = registrar.register_tag tagname, typesym, url, link_text: link_text
      end
      taglink = taghead.search 'a' # See if there's a link to the entity
      if taglink = taglink.first
        # tag = TagServices.define tagname,
        #                          tagtype: typesym,
        #                          page_link: absolutize(taglink)
        tag = registrar.register_tag tagname, typesym, taglink
      end
    end
    extractions = {}
    extractions[tag.typename] = tag.name if tag
    page.search('div#article-list li').each { |li|
      recipe_item li, extractions
    }
    scrape page.links.detect { |link| link.rel?('next') }
    unless url.match /[?&]page=/ # Only scrape the tags on the first page, and only courses
      page.search('div#filter-results div#courses-filters ul li').each { |li|
        define_linked_tag 'courses', li unless (li.content.match 'Other')
      }
    end
  end

  def bbc_occasion_recipes_page
     bbc_tag_recipes_page :Occasion
  end

  def bbc_technique_recipes_page
    bbc_tag_recipes_page :Process
  end

  def bbc_programme_recipes_page
    bbc_tag_recipes_page :Source
  end

  def bbc_course_recipes_page
    bbc_tag_recipes_page :Course
  end

  def bbc_diet_recipes_page
    bbc_tag_recipes_page :Diet
  end

  def bbc_dish_recipes_page
    bbc_tag_recipes_page :Dish
  end

  def bbc_chef_recipes_page
    bbc_tag_recipes_page :Author
  end

  def bbc_cuisine_recipes_page
    bbc_tag_recipes_page :Genre
  end

  def bbc_keyword_recipes_page # Because an ingredient search is denoted like keywords[]=
    bbc_tag_recipes_page :Ingredient
  end

  def define_linked_tag header_name, li
    if link = li.search('a').first
      # Translate from BBC tag types to the RP equivalent
      tagname = li.text.sub(/^\s*Show\s*/,'').sub(/\s*(recipes|\(\d*\)).*$/m,'').strip
      key_name_type = header_name.downcase
      query = nil
      tagtype =
          case key_name_type
            when 'dishes'
              tagname.downcase!
              :Dish
            when 'occasions'
              :Occasion
            when 'ingredients'
              key_name_type = 'keywords'
              query = "keywords=#{tagname.downcase!}"
              :Ingredient
            when 'chefs'
              :Author
            when 'programmes'
              :Source
            when 'courses'
              tagname.downcase!
              :Course
            when 'special diets'
              key_name_type = 'diets'
              tagname.downcase!
              :Diet
            when 'cuisines'
              :Genre
          end
      if link = li.search('a').first
        link_text = CGI.unescape link['href']
        tag_id = nil
        if link_text.match(/\/food\/([-\w]*$)/)
          tag_id = $1
        else
          # Get the last reference to this key_name_type in the link
          while link_text.sub!(/#{key_name_type}((\[[^\]]*\])?=|\/)([^&]*)/, '')
            tag_id = $3
          end
        end
        if tag_id
          scrape absolutize("/food/#{tag_id}") if tagtype == :Dish || tagtype == :Ingredient  # Most home pages can be reached via indexing, but not Dishes'
          query ||= "#{key_name_type}[]=#{tag_id}"
          scrape absolutize("/food/recipes/search?#{query}")
        end
      else
        x=2
      end
      # TagServices.define tagname, :tagtype => Tag.typenum(tagtype) if tagtype
      registrar.register_tag tagname, tagtype if tagtype
    end
  end

  def bbc_recipe_home_page
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

      if link = page.link_with(dom_class: 'chef__link')
        chef_id =
            if m = link.href.match(/chefs(\[[^\]]*\]=|\/)([^&]*)/)
              m[2].to_s
            end
        # extractions['Author'] = TagServices.define(link.to_s,
        #                                                 tagtype: 'Author',
        #                                                 page_link: absolutize(link.href)).name
        extractions['Author'] = registrar.register_tag(link.to_s, :Author, link.href).name
      end

      # Glean ingredient links from the page, meanwhile ensuring the tag is defined
      extractions[:Ingredients] = page.links_with(dom_class: 'recipe-ingredients__link').collect { |link|
        # TagServices.define(link.to_s,
        #                    tagtype: 'Ingredient',
        #                    page_link: absolutize(link.href)).name
        registrar.register_tag(link.to_s, :Ingredient, link.href).name
      }.join ', '

      r = registrar.register_recipe url, extractions.compact
      scrape url
      # Apply the findings, in case the recipe already existed
      r.decorate.findings = FinderServices.from_extractions extractions
    end
  end

  ######### Ingredients ############
  def bbc_ingredients_page
    scrape ('a'..'z').to_a.collect { |letter|
             'http://www.bbc.co.uk/food/ingredients/by/letter/' + letter
           }
  end

  def bbc_ingredients_by_letter
    # e.g., http://www.bbc.co.uk/food/ingredients/by/letter/o
    ingredient_links = page.search('li.resource.food a')
    ingredient_links.each { |link|
      path = link.attribute('href').to_s
      unless path.match(/\A\/food\/([-\w]+)#related-foods\z/)
        img_link = link.search('img').first
        tagname = img_link ? img_link.attribute('alt').to_s : link.text.downcase
        # TagServices.define tagname,
        #                    :tagtype => :Ingredient,
        #                    :page_link => absolutize(link),
        #                    :image_link => (absolutize(img_link.attribute('src')) if img_link)
        registrar.register_tag tagname,
                               :Ingredient,
                               link,
                               :image_link => (img_link.attribute('src') if img_link)
        scrape link
      end
    }
  end

  def bbc_programmes_page
    page.search('li#all-programmes li a').each { |a|
      pid = a.attribute('href').to_s.sub /.*food\/programmes\/(\w*)\b.*$/, '\1'
      if (pname = a.content).present? && !pname.match(/^Series/)
        page_link = absolutize(a)
        # TagServices.define pname, tagtype: Tag.typenum(:Source)
        registrar.register_tag pname, :Source
        scrape page_link
        scrape absolutize('/food/recipes/search?programmes[]=' + pid)
      end
    }
  end

  def bbc_techniques_page
    header_tag_services = nil
    headered_list_items 'dl dt', 'dd' do |header_name, li|
      if header_name == 'Other'
        header_tag_services = nil
      else
        header_tag_services = TagServices.new(
            # TagServices.define header_name, tagtype: Tag.typenum(:Process)
            registrar.register_tag header_name, :Process
        ) unless header_tag_services && header_tag_services.name == header_name
      end
      tech_link = li.search('a').first
      tag_name = tech_link.text.strip
      page_link = absolutize tech_link.attribute('href').to_s
      Rails.logger.info "!!!Scraper Defined Tag Link for '#{tag_name}' -> #{page_link}"
      # tag = TagServices.define  tag_name,
      #                           tagtype: 'Process',
      #                           page_link: page_link
      tag = registrar.register_tag tag_name, :Process, page_link
      header_tag_services.make_parent_of tag if header_tag_services
      scrape page_link
    end
  end

  def bbc_cuisines_page
    page.search('ol#cuisines li.cuisine a').each { |season_link|
      tag_name = season_link.css('span.cuisine-title').text
      page_link = absolutize season_link.attribute('href').to_s
      if img_link = season_link.css('img').attribute('src')
        img_link = absolutize img_link.to_s
      end
      Rails.logger.info "!!!Scraper Defined Tag '#{tag_name}' -> #{page_link} and image link #{img_link}"
      # TagServices.define tag_name,
      #                    tagtype: 'Genre',
      #                    page_link: page_link,
      #                    image_link: img_link
      registrar.register_tag tag_name, :Genre, page_link, image_link: img_link
      scrape page_link
    }
  end

  def bbc_seasons_page
    page.search('a.season-image').each { |season_link|
      tag_name = season_link.css('span.season-name').text
      page_link = absolutize season_link.attribute('href').to_s
      img_link = season_link.css('img').attribute('src').to_s
      # TagServices.define tag_name, tagtype: 'Occasion', page_link: page_link, image_link: img_link
      registrar.register_tag tag_name, :Occasion, page_link, image_link: img_link
      Rails.logger.info "!!!Scraper Defined Tag '#{tag_name}' -> #{page_link} and image link #{img_link}"
      scrape page_link
    }
  end

  # Process the items of a list that is preceded by a header
  def headered_list_items header_selector, sibling_tag='ul', title=nil, &block
    (page.search(header_selector)).each { |hdr|
      hdr_text = hdr.text.to_s.strip
      # Cycle through the following siblings of the header element in search of the
      # one matching the sibling_tag. Terminate when another header tag appears
      div = hdr.next_element
      while div && !(div.matches? header_selector)
        if div.matches? sibling_tag
          div.search('li').each { |li| block.call hdr_text, li } unless title && (title != hdr_text)
          break
        end
        div = div.next_element
      end
      # hdr.search("~ #{sibling_tag}:first li").each { |li| block.call hdr_text, li } unless title && (title != hdr_text)
    }
  end

  def bbc_diet_home_page
    diet_name = page.search('div#column-1 h1').text.downcase.sub /\s.*/, ''
    # diet_tag = TagServices.define diet_name,
    #     :tagtype => :Diet,
    #     :page_link => url
    diet_tag = registrar.register_tag diet_name, :Diet, url
    accordions 'Diet' => diet_name
    headered_list_items 'div.links-module h2', 'ul' do  |header_text, li|
      if header_text == 'Elsewhere on the web'
        see_also_link = li.search('a').first
        # TagServices.define diet_tag,
        #                    page_link: absolutize(see_also_link.attribute('href')),
        #                    link_text: see_also_link.text.strip
        registrar.register_tag diet_tag,
                               see_also_link.attribute('href'),
                               link_text: see_also_link.text.strip
      end
    end
    page.search('a.see-all-search').each { |a| scrape a.attribute('href') }
  end

  def bbc_collection_home_page
    description_item = page.search('div#quote-module p').first
    registrar.register_list (page.search('div#column-1 h1').text + ' (BBC Food)'),
                            :description => (description_item && description_item.text)
    page.search('div#the-collection a').each { |member_link|
      extractions = {}
      rlink = absolutize member_link.attribute('href')
      if rpic = member_link.search('img').first
        extractions['Image'] = absolutize rpic.attribute('src')
      end
      extractions['Title'] = member_link.content.strip
      registrar.add_to_list registrar.register_recipe(rlink, extractions), list
      scrape rlink
    }
    # accordions 'List' => list_name
  end


  def bbc_define_collection cname, home_link, image_link=nil
    registrar.register_list (cname.strip + ' (BBC Food)'),
                            picurl: (absolutize image_link if image_link)
    scrape home_link, :bbc_collection_home_page
  end

  def bbc_recipes_page
    page.search('div.recipe-collections__list a').each { |collection_link|
      cpic = collection_link.search('img').first
      bbc_define_collection collection_link.search('div.recipe-collections__title').first.text,
                            collection_link.attribute('href'),
                            (cpic.attribute('src') if cpic)
    }
  end

  def bbc_technique_home_page
    author_tag =
        if (author_link = page.search 'div#chef-details h2 a').present?
          author_name = author_link.text.strip
          author_page = absolutize author_link.attribute('href')
          if author_pic_link = author_link.search('img').first
            author_pic_link = author_pic_link.attribute('src').to_s
          end
          # TagServices.define author_name, {
          #                                   :tagtype => :Author,
          #                                   :page_link => author_page,
          #                                   :image_link => author_pic_link
          #                               }.compact
          registrar.register_tag author_name, :Author, author_page, :image_link => author_pic_link
        end

    technique_name = page.search('div#column-1 h1').text.strip.downcase
    # technique_tag = TagServices.define technique_name, {
    #                                                      :tagtype => :Process,
    #                                                      :page_link => url,
    #                                                      :suggested_by => author_tag
    #                                                  }.compact
    technique_tag = registrar.register_tag technique_name, :Process, url, :suggested_by => author_tag
    headered_list_items 'div#information-box h2', 'ul' do |header_text, tool_li|
      toolname = tool_li.text.strip.downcase
      # TagServices.define toolname,
      #                    tagtype: 'Tool',
      #                    suggests: technique_tag if toolname.present? && header_text == 'Equipment you will need for this technique'
      registrar.register_tag toolname,
                             :Tool,
                             suggests: technique_tag if toolname.present? && header_text == 'Equipment you will need for this technique'
    end
    page.search('div#overview h4').each { |h4| recipe_item h4, 'Process' => technique_name }

    accordions 'div#recipes-list-module', 'Process' => technique_name

    page.search('a.see-all-search').each { |a| scrape a.attribute('href'), :bbc_technique_recipes_page }
  end

  # Handler that covers dish and ingredient home pages, both of which are like '/food/<name>'
  def bbc_food_home_page
    # The first thing is to distinguish between the two cases by consulting the sub-heading at the top of the page
    if subhead = find_by_selector('p#sub-heading').strip
      typename = subhead.singularize
      tagtype = typename.to_sym
    end

    # INGREDIENT home page
    # DISH home page
    # Recipes for <dish>: dish
    # Recipes using <ingredient>: dish, ingredient
    # <Ingredient> Parts of <ingredient>: dish
    # <Ingredient> Varieties of <ingredient>: dish
    # <Dish> Typically made with <dish>: dish
    # <Ingredients> Other <parent ingred.> (multiple): ingredient

    tagname = page.search('div#column-1 h1').text.strip.sub(/([-\w]*) recipes/, '\1').downcase
    image_link = (absolutize(find_by_selector('img#food-image', :src)) if tagtype == :Ingredient) # No pic for Dishes
    # tag = TagServices.define(tagname, {
    #                                     :tagtype => tagtype,
    #                                     :page_link => url,
    #                                     :image_link => image_link
    #                                 }.compact
    # )
    tag = registrar.register_tag tagname, tagtype, url, :image_link => image_link
    page.search('a.see-all-search').each { |a| scrape a.attribute('href') }
    # The two 'grouped-resource-list-module' accordions have different extractions.
    # The one labeled 'Recipes for' uses the tag in the context of a dish
    # The one labeled 'Recipes using' uses the tag in the context of an ingredient
    # page.search('a.see-all-search').each { |a| launch a.attribute('href'), :bbc_dish_recipes_page }
    n = 1
    page.search('div.grouped-resource-list-module').each { |group|
      if h2 = group.search('h2').first
        case h2.text
          when /Recipes for/
            # TagServices.define(tagname, {
            #                               :tagtype => :Dish,
            #                               :page_link => url,
            #                               :image_link => image_link
            #                           }.compact
            # ) unless tag.typesym == :Dish
            registrar.register_tag( tagname, :Dish, url, :image_link => image_link ) unless tag.typesym == :Dish
            accordions "div.grouped-resource-list-module:nth-of-type(#{n})", 'Dish' => tagname
          when /Recipes using/
            # TagServices.define(tagname, {
            #                               :tagtype => :Ingredient,
            #                               :page_link => url,
            #                               :image_link => image_link
            #                           }.compact
            # ) unless tag.typesym == :Ingredient
            registrar.register_tag( tagname, :Ingredient, url, :image_link => image_link ) unless tag.typesym == :Ingredient
            accordions "div.grouped-resource-list-module:nth-of-type(#{n})", 'Ingredient' => tagname
        end
      end
      n = n+1
    }

    # We determine what category(ies) the entity is in by reference to the 'Other...' links sections in the right column
    headered_list_items 'div#related-foods h3', 'ul' do |title, li|
      case title
        when /^Other(.*)$/
          # parent_tag = TagServices.define($1, tagtype: tag.tagtype)
          parent_tag = registrar.register_tag $1, tag.tagtype, child_of: parent_tag
          # TagServices.new(parent_tag).make_parent_of tag
        when /^Also made with(.*)$/
          # An ingredient that suggests this dish
          # ingred_tag = TagServices.define($1.strip, tagtype: :Ingredient)
          ingred_tag = registrar.register_tag $1.strip, :Ingredient, suggests: tag
          # TagServices.new(ingred_tag).suggests tag
        when /^Typically made with(.*)$/
          # An ingredient that suggests this dish
          # dish_tag = TagServices.define li.content.strip.downcase,
          #                               tagtype: :Dish,
          #                               page_link: absolutize(li.search('a').first)
          dish_tag = registrar.register_tag li.content.strip.downcase,
                                            :Dish,
                                            li.search('a').first,
                                            suggested_by: tag
          # TagServices.new(tag).suggests dish_tag
      end
    end

    # A see-also section within a 'links-module' div
    page.search('div.links-module a').each { |see_also_link|
      # TagServices.define tag, page_link: absolutize(see_also_link.attribute('href'))
      registrar.register_tag tag, see_also_link.attribute('href')
    }

  end

=begin
  def bbc_dish_home_page
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

  def bbc_ingredient_home_page
    # e.g., http://www.bbc.co.uk/food/candied_peel
    tagname =
      if link = page.links_with(href: /\/food\/recipes\/search\b.*\bkeywords=/).first
        link.href.sub /\/food\/recipes\/search\b.*\bkeywords=([-\w\s]*)/, '\1'
      end
    tagname.downcase!
    Rails.logger.info "!!!Scraper Defined Tag '#{tagname}' for #{url}"
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
            TagServices.define(definition_name.downcase,
                               :tagtype => :Ingredient,
                               :page_link => absolutize(definition_link),
                               :image_link => img_link,
                               :kind_of => ingredient_tag)
          when /^Typically made with/
            TagServices.define(definition_name.downcase,
                               :tagtype => :Dish,
                               :page_link => absolutize(definition_link),
                               :image_link => img_link,
                               :suggested_by => ingredient_tag)
        end
      }
    }

    accordions 'Ingredients' => tagname
  end
=end

  def bbc_cuisine_home_page
    genre_name = page.search('div#column-1 h1').text.sub /.*\s([-\w]*\z)/, '\1'
    # genre_tag = TagServices.define(genre_name,
    #                                :tagtype => :Genre,
    #                                :page_link => url)
    genre_tag = registrar.register_tag genre_name, :Genre, url
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
      # TagServices.define genre_tag, page_link: absolutize(see_also_link.attribute('href'))
      registrar.register_tag genre_tag, see_also_link.attribute('href')
    }
  end

  def bbc_programme_home_page
    # The programme_link is the home page of the program on the BBC
    programme_name =
        if programme_link = page.search('div#episode-detail a').first
          programme_link.text.strip # page.search('title').text.sub(/BBC - Food - Recipes from Programmes :/, '').strip
        elsif banner = page.search('div#programme-episode h1').first
          banner.text.sub('recipes', '').strip
        end

    programme_description = page.search('div#episode-detail p').first
    programme_image = find_by_selector('div#programme-brand img', :src)
    # programme_tag = TagServices.define(programme_name,
    #                                    {
    #                                        :tagtype => :Source,
    #                                        :description => (programme_description.text.strip if programme_description),
    #                                        :page_link => url,
    #                                        :image_link => (programme_image if programme_image.present?)
    #                                    }.compact
    # )
    programme_tag = registrar.register_tag programme_name,
                                           :Source,
                                           url,
                                           :description => (programme_description.text.strip if programme_description),
                                           :image_link => (programme_image if programme_image.present?)
    # Define the reference to the program page
    # TagServices.define programme_tag, page_link:
    #                                     (absolutize(programme_link.attribute('href')) if programme_link) ||
    #                                         url.sub('/food/programmes/', '/programmes/')
    registrar.register_tag programme_tag, (programme_link ?
                                        programme_link.attribute('href') :
                                        url.sub('/food/programmes/', '/programmes/'))
    headered_list_items 'div.related-resources-module h2', 'ul' do |header_name, li|
      if header_name == 'Related chefs'
        link = li.search('a').first
        img = link.search('img').first
        chef_name = img.attribute('alt').to_s
        chef_img = img.attribute('src').to_s
        chef_link = absolutize link.attribute('href').to_s
        # chef_tag = TagServices.define chef_name, {
        #                                            tagtype: :Author,
        #                                            page_link: chef_link,
        #                                            image_link: chef_img
        #                                        }.compact
        chef_tag = registrar.register_tag chef_name, :Author, chef_link, image_link: chef_img
        TagServices.new(programme_tag).suggests chef_tag
      end
    end

    # The seemore link finds all recipes under that programme
    if seemore = page.search('p.see-all a.see-all-search').first
      scrape seemore.attribute('href')
    end

  end

  def bbc_season_home_page
    month_name = page.search('div#column-1 h1').text.sub /.*\s([-\w]*\z)/, '\1'
    # month_tag = TagServices.define(month_name,
    #                                :tagtype => :Occasion,
    #                                :page_link => url)
    month_tag = registrar.register_tag month_name, :Occasion, url
    accordions 'Occasion' => month_name
    page.search('div#related-ingredients li a').each { |page_link|
      # ingred_tag = TagServices.define( page_link.text.downcase,
      #                                  :tagtype => :Ingredient,
      #                                  :page_link => absolutize(page_link))
      ingred_tag = registrar.register_tag page_link.text.downcase, :Ingredient, page_link
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
      # TagServices.define occ_name.to_s, {
      #                                     tagtype: :Occasion,
      #                                     page_link: occ_link,
      #                                     image_link: absolutize(img_link)
      #                                 }.compact
      registrar.register_tag occ_name.to_s, :Occasion, occ_link, image_link: img_link
      scrape occ_link
    }
  end

  def bbc_occasion_home_page
    occ_name = find_by_selector('h1').strip
    occ_name.sub! /\b\s*recipes.*$/, ''
    # occ_tag = TagServices.define occ_name, tagtype: Tag.typenum(:Occasion), page_link: url
    occ_tag = registrar.register_tag occ_name, :Occasion, url
    if seemore = find_by_selector('p.see-more a.see-all-search', :href)
      scrape seemore
    end
    accordions 'Occasion' => occ_name
    occ_svcs = nil
    page.search('div#related-collections li a').each { |alink|
      imglink = alink.search('img')
      bbc_define_collection alink.text.strip, alink['href'], ((imglink.attribute 'src') if imglink)
    }
    headered_list_items 'div.related-resources-module h3' do |resource_type, li|
      if related_tag = define_linked_tag(resource_type, li)
        occ_svcs ||= TagServices.new(occ_tag)
        occ_svcs.suggests related_tag
      end
    end
  end

end
