class PageRefDecorator < Draper::Decorator
  include Templateer
  delegate_all

  def name
    # The name by which the reference is referred to is either
    # 1) the link_text of the reference (preferred), or
    # 2) the name of the canonical expression of the reference's first referent
    if object.title.present?
      object.title
    elsif object.is_a?(Referrable) && object.referents.first
      object.referents.first.name
    end
  end

  def title
    name || url
  end

  def external_link
    url
  end

end