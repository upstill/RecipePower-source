require 'scraping/scanner.rb'
class RecipePage < ApplicationRecord
  include Pagerefable
  include Backgroundable
  backgroundable

  include Trackable
  attr_trackable :content

  def self.mass_assignable_attributes
    [ :content ]
  end

  has_one :page_ref
  accepts_nested_attributes_for :page_ref
  has_many :recipes, :through => :page_ref

  ############# Backgroundable #############

  def perform
    # NB: we don't block on the PageRef to avoid circular dependency
    # page_ref.ensure_attributes :content
    if content_needed? && page_ref.content_ready?
      content = page_ref.trimmed_content
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
          end || rset.find { |r| r.anchor_path.nil? }
          if title.present? # There's an existing recipe
            if recipe
              recipe.accept_attribute :title, title, true
              recipe.anchor_path, recipe.focus_path = xb
              # recipe.accept_attribute(:anchor_path, xb.first, true) { |attrname| recipe.accept_attribute :content, nil}
              # recipe.accept_attribute(:focus_path, xb.last, true) { |attrname| recipe.accept_attribute :content, nil}
            else
              rcp = page_ref.recipes.build title: title, anchor_path: xb.first, focus_path: xb.last
            end
=begin
            if recipe&.persisted?
              recipe.update_column :title, title
              if recipe.anchor_path != xb.first || recipe.focus_path != xb.last
                recipe.update_column :anchor_path, xb.first
                recipe.update_column :focus_path, xb.last
                recipe.update_column :content, nil
              end
            elsif recipe
              recipe.title = title
              if recipe.anchor_path != xb.first || recipe.focus_path != xb.last
                recipe.anchor_path = xb.first
                recipe.focus_path = xb.last
                recipe.content = nil
              end
            else
              rcp = page_ref.recipes.build title: title, anchor_path: xb.first, focus_path: xb.last
            end
=end
          end
          puts sub_parser.report_for(:rp_title) { |title_seekers| "Parsed out recipe '#{title_seekers.first.to_s}'" }
          # puts sub_parser.report_for(:except => :rp_title) # All other token types
        end
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
