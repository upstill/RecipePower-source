require 'string_utils.rb'

class TaggableDecorator < Draper::Decorator
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
    strjoin (object.tags + object.tags(User.super_id)).uniq.select { |tag|
      matching_types.nil? || (matching_types.include? tag.tagtype)
    }.collect { |tag|
      h.link_to_modal tag.name, tag, class: "rcp_list_element_tag"
    }
  end

end