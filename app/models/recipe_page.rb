require 'scraping/scanner.rb'
class RecipePage < ApplicationRecord
  include Pagerefable
  pagerefable :url
  include Taggable
  include Collectible
  picable :picurl, :picture
  include Backgroundable
  backgroundable

  include Trackable
  attr_trackable :content, :picurl, :title

  accepts_nested_attributes_for :page_ref

  has_many :recipes, :through => :page_ref

  def self.mass_assignable_attributes
    (defined?(super) ? super : []) + [ :content, :picurl, :title, :url, :page_ref_attributes => (PageRef.mass_assignable_attributes + [ :id, recipes_attributes: [:title, :id, :anchor_path, :focus_path] ] )  ]
  end

  ############# Backgroundable #############

  # In order to make our content, we need content from the PageRef
  def request_dependencies
    page_ref.request_attributes *(needed_attributes & [ :content, :picurl, :title ]) # , :description
    adopt_dependencies # If the PageRef has already satisfied our needs
  end

  def adopt_dependencies
    super if defined? super
    # Get the available attributes from the PageRef
    # Translate what the PageRef is offering into our attributes
    needed_from_page_ref = needed_attributes & PageRef.tracked_attributes
    page_ref.ensure_attributes *needed_from_page_ref if needed_from_page_ref.present?
    accept_attribute :picurl, page_ref.picurl if page_ref.picurl_ready?
    accept_attribute :title, page_ref.title if page_ref.title_ready?
    accept_attribute :description, page_ref.description if page_ref.description_ready?
  end

  def perform
    # NB: we don't block on the PageRef to avoid circular dependency
    # page_ref.ensure_attributes :content
    if content_needed? && page_ref.content_ready?
      # Clear all recipes but the first
      content = page_ref.trimmed_content
      if content.present?
        # rset.each { |rcp| rcp.anchor_path = rcp.focus_path = nil }
        # parser = ParsingServices.new self
        # We expect the recipe page to get parsed out into multiple recipes, but only expect to find the title
        # parser.parse content
        # Apply the results of the parsing by ensuring there are recipes for each section
        # The seeker should present the token :rp_recipelist and have several children
        # We assume that any existing recipes match the parsed-out recipes in creation (id) order
        rcpdata = []
        # parser.do_for(:rp_recipe) do |sub_parser| # Focus on each recipe in turn
        ParserServices.parse(entity: self).do_for(:rp_recipe) do |sub_parser| # Focus on each recipe in turn
          xb = sub_parser.xbounds
          rcpdata << { title: (sub_parser.value_for :rp_title), anchor_path: xb.first, focus_path: xb.last }
        end

        # Try to match existing recipes on selection, collecting those that don't match
        unresolved = []
        page_ref.recipes.each do |recipe|
          # Keep recipes that can't be matched on path
          if rcpdi = rcpdata.find_index { |rcpdatum| recipe.anchor_path == rcpdatum[:anchor_path] && recipe.focus_path == rcpdatum[:focus_path] }
            rcpdata.delete_at rcpdi
          else
            unresolved << recipe
          end
        end

        # Match by titles on recipes that didn't match by selection
        unresolved.keep_if do |recipe|
          if rcpdi = rcpdata.find_index { |rcpdatum| recipe.title == rcpdatum[:title] }
            rcpdatum = rcpdata[rcpdi]
            recipe.anchor_path = rcpdatum[:anchor_path]
            recipe.focus_path = rcpdatum[:focus_path]
            rcpdata.delete_at rcpdi
          end
          rcpdi.nil?
        end

        # Assign remaining data to random unresolved recipes
        unresolved.sort_by { |recipe| recipe.collector_pointers.size }
        while rcpdata.present? && unresolved.present? do
          existing_rcp = unresolved.pop
          rcpdatum = rcpdata.pop
          existing_rcp.accept_attribute :title, rcpdatum[:title], true
          existing_rcp.anchor_path = rcpdatum[:anchor_path]
          existing_rcp.focus_path = rcpdatum[:focus_path]
        end

        # Build recipes from any data that hasn't found a home
        page_ref.recipes.create rcpdata

        # Finally, if we've run out of found recipes and there are still some unresolved, destroy them
        page_ref.recipes.destroy *unresolved

        accept_attribute :content, content
      end
    end
  end

  # Return the content within the selection. Presumably this is the actual content of a recipe. There may also be
  # multiple selections on a page, each for a different recipe.
  def selected_content anchor_path, focus_path
    return content unless anchor_path.present? && focus_path.present?
    nk = Nokogiri::HTML.fragment content
    anchor_node = nk.xpath(anchor_path.downcase)&.first   # Presumably there's only one match!
    focus_node = nk.xpath(focus_path.downcase)&.first
    return unless anchor_node && focus_node
    # Degenerate case where the selection only has one node
    return anchor_node.to_html if anchor_node == focus_node

    nokotree = assemble_tree_from_nodes anchor_node, focus_node, :tag => :div, :rp_elmt_class => :rp_recipe
    nokotree.to_html if nokotree
  end

end
