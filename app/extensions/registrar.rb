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
  def register_recipe link_or_page_or_hash, extractions={}
    link_or_page =
    if link_or_page_or_hash.is_a? Hash
      title = link_or_page_or_hash[:title]
      link_or_page_or_hash[:url]
    else
      link_or_page_or_hash
    end
    recipe_link =
        if link_or_page.is_a?(Mechanize::Page)
          title ||= link_or_page.search('title').try :text
          extractions.merge!('Title': title) if title
          link_or_page.uri.to_s
        else
          link_or_page
        end
    recipe = CollectibleServices.find_or_create({url: absolutize(recipe_link), title: title}.compact,
                                                extractions,
                                                Recipe)
    Rails.logger.info "!!!Scraper Defined Recipe at #{absolutize recipe_link}:"
    extractions.each { |key, value| Rails.logger.info "!!!Scraper Defined Recipe        #{key}: '#{value}'" }
    Rails.logger.info ''
    recipe
  end

  # Commit the link in association with a tag
=begin
  def self.register_link_for_tag tagname, link, ts_options
    link = absolutize link
    if Rails.development?
      logger.debug "#{link} gets linked to tag #{tagname}"
      ts_options.each { |name, val| logger.debug "    #{name} => #{val}" }
    else
      TagServices.define tagname, ts_options.merge(page_link: link)
    end
  end

=end
  # Associate a name with a tag, or add a page_link to an existing tag
  # name_or_tag: a string or a Tag instance;
  # tagtype: required to give the tag type if name_or_tag is a string
  #     (tagtype omitted if already a tag)
  # page_link_or_page_ref (optional): either a URL or a PageRef denoting a page to associate with the tag
  # options: other info useful to TagServices.define
  #   :tag_ref: a Referent which the tag will express (created if not given)
  #   :page_kind: how the PageRef will be classified if it needs to be created
  #   :image_link: for an image to be associated with the reference
  #   :link_text: passed to the page_ref for labeling its URL in links
  #   :description: description of the associated referent
  #   :parent_tag: tag to be a parent of the asserted tag
  #   :child_tag: tag to be a child of the asserted tag
  #   :suggests: tag to be suggested by the asserted tag
  #   :suggested_by: tag that will suggest the asserted tag
  def register_tag name_or_tag, tagtype=nil, page_link_or_page_ref=nil, options={}
    if name_or_tag.is_a?(Tag)
      page_link_or_page_ref, options = tagtype, page_link_or_page_ref
    else
      options[:tagtype] = tagtype
    end
    if page_link_or_page_ref.is_a?(Hash)
      options, page_link_or_page_ref = page_link_or_page_ref, nil
    end
    if page_link_or_page_ref.is_a? PageRef
      options[:page_ref] = page_link_or_page_ref
    else
      options[:page_link] = absolutize page_link_or_page_ref
    end
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
  # title_or_tag_or_referent: denotes a tag whose referent will be associated with the product (all of which are required)
  # page_link_or_page_ref: URL for the product page, or the page_ref thus derived
  # options:
  #    title: the title to be given to the product (if that won't be the same as the tag's name)
  def register_product tagname_or_tag, page_link_or_page_ref, options={}
    tagname = (tagname_or_tag.is_a? Tag) ? tagname_or_tag.name : tagname_or_tag
    # We may provide a page_ref for the product directly
    if page_link_or_page_ref.is_a?(PageRef)
      product_pageref = page_link_or_page_ref
    else
      # Otherwise, find or create a page_ref for the product
      product_pageref = PageRefServices.assert :product, page_link_or_page_ref.to_s
      product_pageref.save
      product_pageref.bkg_launch
    end

    # Find or create a product for the page_ref
    product = Product.create_with(title: (options[:title] || tagname)).find_or_create_by(page_ref: product_pageref)

    # Give the product a referent as necessary
    if tagname.present? # The Product page doesn't necessarily come with a tag
      if product_referent = product.referents.first
        product_referent.express tagname_or_tag # Make it a synonym on the existing tags
      else
        product_referent = Referent.express tagname_or_tag, :Ingredient
        product.referents << product_referent.becomes(Referent)
      end
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
