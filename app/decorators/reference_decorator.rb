class ReferenceDecorator < ModelDecorator
  delegate_all

  def name
    # The name by which the reference is referred to is either
    # 1) the link_text of the reference (preferred), or
    # 2) the name of the canonical expression of the reference's first referent
    if link_text.present?
      link_text
    elsif referents.first
      referents.first.name
    elsif affiliate
      affiliate.decorate.title
    end
  end
  alias_method :title, :name

  def dom_id
    "#{object.model_name.singular}_#{object.id}"
  end
end
