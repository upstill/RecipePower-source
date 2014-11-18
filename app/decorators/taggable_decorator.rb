require 'string_utils.rb'

class TaggableDecorator < Draper::Decorator
  attr_accessor :viewer_id

  def extract tagtype=nil
    matching_types =
    case tagtype
      when "Other"
        [Tag.typenum("Culinary Term"), Tag.typenum("Untyped")]
      when nil
        nil
      else
        [Tag.typenum(tagtype)]
    end
    strjoin object.tags_visible_to(@viewer_id).uniq.select { |tag|
      matching_types.nil? || (matching_types.include? tag.tagtype)
    }.collect { |tag|
      h.link_to_submit tag.name, tag, :mode => :modal, class: "rcp_list_element_tag"
    }
  end

end
