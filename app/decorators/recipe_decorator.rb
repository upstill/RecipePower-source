require 'string_utils.rb'

class RecipeDecorator < TaggableDecorator

  def extract fieldname
    case fieldname
      when /_tags$/
      tagtype = fieldname.sub /_tags$/, ''
      super(tagtype)
    when /^rcp/
      attrname = fieldname.sub( /^rcp/, '').downcase
      case attrname
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
"rcpPicData"
"rcpPicLink"
"rcpPrivate"
"rcpStatus"
"rcpTitle"
"rcpTitle"

"site"
~

=end
end
