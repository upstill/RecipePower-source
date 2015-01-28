class String
  def if_empty fallback=nil
    empty? ? fallback : self
  end
end

class UserPresenter < BasePresenter
  presents :user
  delegate :username, :fullname, :handle, :lists, :feeds, to: :user

  def avatar
    img = user.image
    img = "default-avatar-128.png" if img.blank?
    site_link image_with_error_recovery(img, class: "avatar media-object", alt: "/assets/default-avatar-128.png") # image_tag("avatars/#{avatar_name}", class: "avatar")
  end

  def member_since
    user.created_at.strftime("%B %e, %Y")
  end

  def linked_name
    site_link(user.fullname.present? ? user.fullname : user.username)
  end

  def aspect which, viewer=nil
    label = which.to_s.capitalize.tr('_', ' ') # split('_').map(&:capitalize).join
    contents = nil
    case which
      when :member_since
        contents = member_since
      when :about
        contents = user.about
      when :collected_feeds
        label = "Following the feeds"
        contents = strjoin(feeds.collect { |feed|
                            link_to_submit feed.title, feed_path(feed), :mode => :partial
                          }).html_safe
      when :collected_lists, :owned_lists
        if which == :owned_lists
          lists = user.visible_lists viewer
          label = "Created the lists"
        else
          lists = user.collected_entities List, viewer
          label = "Following the lists"
        end
        unless lists.empty?
          contents = strjoin(
              lists.collect { |list|
                link_to_submit list.name, list_path(list), :mode => :partial
              }).html_safe
        end
    end
    content_tag(:h4, "#{label}: #{content_tag :small, contents}".html_safe) if contents
  end

  def about
    handle_none user.about do
      markdown(user.about)
    end
  end

  def tags
    user.tags.collect { |tag| tag.name }.join(', ')
  end

  private

  def handle_none(value)
    if value.present?
      yield
    else
      h.content_tag :span, "None given", class: "none"
    end
  end

  def site_link(content)
    content # h.link_to_if(user.url.present?, content, user.url)
  end

  def avatar_name
    if user.avatar_image_name.present?
      user.avatar_image_name
    else
      "default.png"
    end
  end
end
