require 'string_utils.rb'

class RecipeDecorator < Draper::Decorator

  def extract fieldname
    case fieldname
    when /_tags$/
      tagtype = fieldname.sub /_tags$/, ''
      matching_types = tagtype == "Other" ?
          [Tag.typenum("Culinary Term"), Tag.typenum("Untyped")] :
          [Tag.typenum(tagtype)]
      strjoin object.tags.select { |tag| matching_types.include? tag.tagtype }.collect { |tag|
        h.link_to_modal tag.name, tag, class: "rcp_list_element_tag"
      }
    when /^rcp/
      attrname = fieldname.sub( /^rcp/, '').downcase
      case attrname
      when "private"
        object.private ? %q{checked="checked"} : ""
      when "picsafeurl"
        object.picurl.blank? ? "/assets/NoPictureOnFile.png" : object.picurl
      when "titlelink"
        h.link_to object.title, object.url
      when "video"
        (vid = YouTubeAddy.extract_video_id(object.url)) && "http://www.youtube.com/embed/#{vid}"
      else
        object.send(attrname.to_sym).to_s if object.respond_to? attrname
      end
    when /^comments/
      case fieldname.sub( /^comments_/, '')
        when "mine"
        when "friends"
        when "others"
      end
    when "site"
      h.link_to object.sourcename, object.sourcehome
    end
  end
=begin
"Channel_tags"
"Genre_tags"
"Ingredient_tags"
"Occasion_tags"
"Process_tags"
"Role_tags"
"Source_tags"
"Tool_tags"
"Author_tags"

"Other_tags"

"comments_mine"
"comments_mine"

"rcpComment"
"rcpID"
"rcpPicSafeURL"
"rcpPicURL"
"rcpPrivate"
"rcpStatus"
"rcpTitle"
"rcpTitle"

"site"
~

=end
end
