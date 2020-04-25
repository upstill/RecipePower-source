require 'scraping/scanner.rb'
class RecipePage < ApplicationRecord
  include Pagerefable
  include Backgroundable
  backgroundable

  def self.mass_assignable_attributes
    [ :content ]
  end

  has_one :page_ref
  accepts_nested_attributes_for :page_ref
  has_many :recipes, :through => :page_ref

  # Trigger the page_ref and the associated gleaning as necessary
  def bkg_launch force=false
    if content.blank?
      page_ref.bkg_launch
      force = true
    end
    super(force) if defined?(super)
  end

  # As a Pagerefable, this is called by #perform once the page_ref has landed successfully
  def adopt_page_ref
    if content.blank?
      # The first time content is adopted from our page_ref, parse it for recipe content
      content = SiteServices.new(page_ref.site).trim_recipe page_ref.content
      if content.present?
        parser = ParsingServices.new self
        # We expect the recipe page to get parsed out into multiple recipes, but only expect to find the title
        parser.parse content
        # Apply the results of the parsing by ensuring there are recipes for each section
        # The seeker should present the token :rp_recipelist and have several children
        rset = page_ref.recipes.to_a
        # We assume that any existing recipes match the parsed-out recipes in creation (id) order
        parser.do_for(:rp_recipe) do |sub_parser| # Focus on each recipe in turn
          title = sub_parser.value_for :rp_title
          xb = sub_parser.xbounds
          recipe = rset.find do |r|
            (r.anchor_path == xb.first && r.focus_path == xb.last) || (r.title == title)
          end
          if title.present? # There's an existing recipe
            if recipe&.persisted?
              recipe.update_column :title, title
              recipe.update_column :anchor_path, xb.first
              recipe.update_column :focus_path, xb.last
            elsif recipe
              recipe.title = title
              recipe.anchor_path = xb.first
              recipe.focus_path = xb.last
            else
              rcp = page_ref.recipes.build title: title, anchor_path: xb.first, focus_path: xb.last
            end
          end
          puts sub_parser.report_for(:rp_title) { |title_seekers| "Parsed out recipe '#{title_seekers.first.to_s}'" }
          # puts sub_parser.report_for(:except => :rp_title) # All other token types
        end
        self.content = content # Copied directly from page_ref
=begin
      recipe_seekers = parser.seeker.find { |child| child.token == :rp_recipe && child.find(:rp_title).present? }
      recipe_seekers.each do |recipe_seeker|
        title_seeker = recipe_seeker.find(:rp_title).first
        puts "Parsed out recipe '#{title_seeker.to_s}'"
        ingredients = recipe_seeker.find(:rp_ingname)
        report 'ingredients', ingredients
        rp_yield = recipe_seeker.find(:rp_yield)
        report 'yield', rp_yield
        author = recipe_seeker.find(:rp_author)
        report 'author', author
        makes = recipe_seeker.find(:rp_makes)
        report 'makes', makes
      end
=end
      end
    end
  end

  # Return the content within the selection. Presumably this is the actual content of a recipe. There may also be
  # multiple selections on a page, each for a different recipe.
  def selected_content anchor_path, focus_path
    return unless anchor_path.present? && focus_path.present?
    nk = Nokogiri::HTML.fragment content
    anchor_node = nk.xpath(anchor_path.downcase)&.first   # Presumably there's only one match!
    focus_node = nk.xpath(focus_path.downcase)&.last
    return unless anchor_node && focus_node
    if anchor_node == focus_node
      # Degenerate case where the selection only has one node
      return anchor_node.to_html
    end
    nokotree = assemble_tree_from_nodes anchor_node, focus_node, :tag => :div, :classes => :rp_recipe, insert: false
    nokotree.to_html if nokotree
  end

end
