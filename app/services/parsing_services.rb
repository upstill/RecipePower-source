class ParsingServices
  attr_accessor :recipe

  def initialize recipe=nil
    @recipe = recipe
  end

  # annotate: apply a parsing token to the given html, using the XML paths denoting the selection
  def annotate html, token, anchor_path, anchor_offset, focus_path, focus_offset
    nkdoc = Nokogiri::HTML.fragment html
    nokoscan = NokoScanner.new nkdoc
    nokoscan.tokens.enclose_by_selection anchor_path, anchor_offset.to_i, focus_path, focus_offset.to_i, token
    nkdoc.to_s
  end
end