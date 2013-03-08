class String
  def if_empty fallback=nil
    empty? ? fallback : self
  end
end

class UserPresenter < BasePresenter
  presents :user
  delegate :username, to: :user
  delegate :fullname, to: :user

  def avatar
    site_link image_tag(user.image.if_empty("default-avatar-128.png"), class: "avatar" )# image_tag("avatars/#{avatar_name}", class: "avatar")
  end

  def member_since
    user.created_at.strftime("%B %e, %Y")
  end

  def linked_name
    site_link(user.fullname.present? ? user.fullname : user.username)
  end

=begin
  def website
    handle_none user.url do
      h.link_to(user.url, user.url)
    end
  end

  def twitter
    handle_none user.twitter_name do
      h.link_to user.twitter_name, "http://twitter.com/#{user.twitter_name}"
    end
  end
=end

  def about
    handle_none user.about do
      markdown(user.about)
    end
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