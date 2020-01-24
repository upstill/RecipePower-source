require 'nokogiri'

# Perform whatever processing is needed on the node
def process_dom html
  nk = Nokogiri::HTML::fragment html
  nk.traverse do |node|
    case
    when node.cdata? # type == CDATA_SECTION_NODE
    when node.comment? # type == COMMENT_NODE
    when node.element? # type == ELEMENT_NODE alias node.elem?
      case node.name
      when 'br', 'p'
        node.previous.remove if node.previous&.element? && node.previous.name == 'br'
      end
    when node.fragment? # type == DOCUMENT_FRAG_NODE (Document fragment node Nokogiri::HTML::DocumentFragment/11)
    when node.html? # type == HTML_DOCUMENT_NODE
    when node.xml? # type == DOCUMENT_NODE (Document node type)
    when node.text? # type == TEXT_NODE (Nokogiri::XML::Text/3)
      # From text, replace all internal newlines with a space
      node.content = node.text.gsub /\s*\n+\s*/, ' '
      # node.remove if node.text.match /^\s*$/
    when node.document?
      # For elements, remove CSS classes
    when node.xml?
    when node.fragment?
    else
      puts "Unknown Nokogiri node #{node.class} (node_type = #{node.node_type}"
    end
  end
  nk.to_s
end