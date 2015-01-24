class CollectibleDecorator < Draper::Decorator
  include Templateer
  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end
  def arity fieldname
    case fieldname.downcase
      when /_tags$/
        tagtype = fieldname.sub /_tags$/, ''
        tagtype = ["Culinary Term", "Untyped"] if tagtype=="Other"
        tags_visible_to(object.collectible_user_id, :tagtype => tagtype).count
      when "list", "lists"
        ListServices.find_by_listee(object).count
    end
  end

  def extract fieldname
    case fieldname.downcase
      when /_tags$/
        tagtype = fieldname.sub /_tags$/, ''
        tagtype = ["Culinary Term", "Untyped"] if tagtype=="Other"
        strjoin tags_visible_to(object.collectible_user_id, :tagtype => tagtype).collect { |tag|
                  h.link_to_submit tag.name, tag, :mode => :modal, class: "rcp_list_element_tag"
                }
      when /^rcp/
        attrname = fieldname.sub(/^rcp/, '').downcase
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
        case fieldname.sub(/^comments_/, '')
          when "mine"
          when "friends"
          when "others"
        end
      when "site"
        h.link_to object.sourcename, object.sourcehome
      when "list", "lists"
        strjoin ListServices.find_by_listee(object).collect { |list|
                  llink = h.link_to_submit list.name, list, mode: :partial, class: "rcp_list_element_tag"
                  if list.owner_id == object.tagging_user_id
                    llink
                  else
                    ulink = h.link_to list.owner.handle, list.owner, mode: :partial, class: "rcp_list_element_tag"
                    "#{llink} (#{ulink})".html_safe
                  end
                }
      when "classname_lower"
        object.class.to_s.downcase
      else
        method(fieldname.to_sym).call rescue nil
    end
  end

  def picdata site_fallback=false
    object.picdata || (site_fallback && (object.site.picdata rescue nil))
  end
end
