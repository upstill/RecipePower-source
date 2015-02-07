class SitePresenter < CollectiblePresenter
  attr_accessor :site
  delegate :name, :fullname, :lists, :feeds, to: :site

  def initialize decorator, template
    super
    @site = decorator.object
  end

  def avatar
    img = site.logo
    img = "default-avatar-128.png" if img.blank?
    site_link image_with_error_recovery(img, class: "avatar media-object", alt: "/assets/default-avatar-128.png" )
  end

  def header
    link_to site.name, site.home
  end

  def aspect which, viewer=nil, options = {}
    if viewer.is_a? Hash
      viewer, options = nil, viewer
    end
    label = which.to_s.capitalize.tr('_', ' ') # split('_').map(&:capitalize).join
    contents = nil
    case which
      when :description
        contents = site.description
      when :author
        tags = site.visible_tags :tagtype => :Author
        label = label.pluralize unless tags.empty?
        contents = tag_list tags
      when :tags
        tags = site.visible_tags :tagtype => [:Genre, :Role, :Ingredient, :Source, :Occasion, :Tool]
        label = label.pluralize unless tags.empty?
        contents = tag_list tags
      when :lists # Lists it appears under
        # TODO Shoud be including option of indirect linkage i.e. being tagged with a list's tag
        label = "Seen on list(s)"
        content = strjoin(site.visible_tags(tagtype: :List).collect { |list_tag|
          link_to_submit(list.name, list_path(list), :mode => :partial)
        }).html_safe
    end
    content_tag( :tr, (content_tag(:td, content_tag(:h4, label), style: "padding: 10px; padding-top: 0px; vertical-align:top;" )+
                       content_tag(:td, contents, style: "padding: 10px; padding-top: 10px;")).html_safe ) unless contents.blank?
  end

  def aspects
    [ :author, :description, :tags, :title ].collect { |this| aspect(this) }.compact.join.html_safe
  end

=begin
  def about
    handle_none user.about do
      markdown(user.about)
    end
  end

  def tags
    user.tags.collect { |tag| tag.name }.join(', ')
  end
=end

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
