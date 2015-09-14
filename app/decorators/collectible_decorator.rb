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
        visible_tags(:tagtype => tagtype).count
      when "list", "lists"
        ListServices.find_by_listee(object).count
    end
  end

  def extract fieldname
    case fieldname.downcase
      when /_tags$/
        tagtype = fieldname.sub /_tags$/, ''
        tagtype = ["Culinary Term", "Untyped"] if tagtype=="Other"
        strjoin visible_tags(:tagtype => tagtype).collect { |tag|
                  h.link_to_submit tag.name, tag, :mode => :modal, class: "rcp_list_element_tag"
                }
      when /^tags$/
        taglist = visible_tags.collect { |tag|
          h.link_to_submit(tag.name.downcase, tag, :mode => :modal, :class => "taglink" )
        }.join('&nbsp;<span class="tagsep">|</span> ')
        # <span class="<%= recipe_list_element_golink_class item %>">
        button = h.collectible_tag_button self, {}
        (taglist+"&nbsp; "+button).html_safe
      when /^rcp/
        attrname = fieldname.sub(/^rcp/, '').downcase
        case attrname
          when "picsafeurl"
            object.imgdata(true)
          when "titlelink"
            h.link_to object.title, object.url
          when "video"
            (uri = URI(object.url)) &&
            uri.host.match(/\.youtube.com/) &&
            (vid = YouTubeAddy.extract_video_id(object.url)) &&
            "https://www.youtube.com/embed/#{vid}"
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
        h.link_to object.sourcename, object.sourcehome, class: "tablink"
      when "list", "lists"
        strjoin ListServices.find_by_listee(object).collect { |list|
                  llink = h.link_to_submit list.name, list, class: "rcp_list_element_tag"
                  if list.owner_id == object.tagging_user_id
                    llink
                  else
                    ulink = h.link_to list.owner.handle, list.owner, class: "rcp_list_element_tag"
                    "#{llink} (#{ulink})".html_safe
                  end
                }
      when "collections"
        strjoin CollectibleServices.new(object).collectors.collect { |user|
          h.link_to_submit( user.handle, h.user_path(user), :mode => :modal) unless user.id == object.tagging_user_id
        }.compact
      when "feeds"
        strjoin(object.feeds.where(approved: true).collect { |feed| h.link_to_submit feed.title, h.feed_path(feed) },"","",',', '<br>').html_safe
      when "classname_lower"
        object.class.to_s.downcase
      else
        (method(fieldname.to_sym).call rescue nil) || ""
    end
  end

  # Collectibles are editable by default
  def read_only
    false
  end

  # Build an entity and its decorator based on type and ID of an existing object
  def self.build entity_type, entity_id
    entity_type.constantize.find(entity_id).decorate rescue nil
  end

  # sample_page is a full URL somewhere on the associated site so we can absolutize links
  def sample_page

  end

  def fallback_img
    object.fallback_imgdata if object.respond_to?(:fallback_imgdata)
  end

  def picurl
    picurl = object.imglink
    (picurl.present? && sample_page) ? valid_url(picurl, sample_page) : picurl
  end

  def pageurl
    if object.respond_to?(:url_attribute)
      pageurl = object.url_attribute
      (pageurl.present? && sample_page) ? valid_url(pageurl, sample_page) : pageurl
    end
  end

end
