require 'scraping/scanner.rb'
class RecipePage < ApplicationRecord
  include Backgroundable
  backgroundable

  def self.mass_assignable_attributes
    [ :content ]
  end

  has_one :page_ref
  accepts_nested_attributes_for :page_ref
  has_many :recipes, :through => :page_ref

  # The page performs by parsing the content from its page_ref
  def perform
    if content.blank?
      # Need to get content from page_ref before we can do anything
      if page_ref # Finish doing any necessary gleaning of the page_ref
        page_ref.bkg_land
        if page_ref.good?
          self.content = SiteServices.new(page_ref.site).trim_recipe page_ref.content
        else
          err_msg = "Page at '#{url}' can't be gleaned: PageRef ##{page_ref.id} sez:\n#{page_ref.error_message}"
          errors.add :url, err_msg
          raise err_msg if page_ref.dj # PageRef is ready to try again => so should we be, so restart via Delayed::Job
        end
      end
    end

    # Now we presumably have valid content. Now to parse it.
    parse if content.present?
    save
  end

  def parse

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
    classes = "rp_elmt #{classes}".strip
    nokotree = assemble_tree_from_nodes "<div class='#{classes}'></div>", anchor_node, focus_node, false
    nokotree.to_html if nokotree
  end

end
