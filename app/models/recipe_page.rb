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
    nk = Nokogiri::HTML.fragment content
    anchor_node = nk.xpath(anchor_path.downcase).first   # Presumably there's only one match!
    focus_node = nk.xpath(focus_path.downcase).last
    if anchor_node == focus_node
      # Degenerate case where the selection only has one node
      return anchor_node
    end
    classes = "rp_elmt #{classes}".strip
    newtree = Nokogiri::HTML.fragment "<div class='#{classes}'></div>"
    # We return the lowest common ancestor of the two nodes,
    # trimmed of all children to the anchor's left and the focus's right
    minimal_common.to_html
    common_ancestor = (anchor_node.ancestors & focus_node.ancestors).first
    highest_whole_left = anchor_node
    while (highest_whole_left.parent != common_ancestor) && !highest_whole_left.previous_sibling do
      highest_whole_left = highest_whole_left.parent
    end

    # Starting with the highest whole node, add nodes of the selection to the new elmt
    elmt = highest_whole_left.next
    newtree.add_child highest_whole_left
    while (elmt.parent != common_ancestor)
      parent = elmt.parent
      while (right_sib = elmt.next) do
        elmt = right_sib.next
        newtree.add_child right_sib
      end
      elmt = parent
    end

  end

end
