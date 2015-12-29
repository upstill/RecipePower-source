class ReferentDecorator < Draper::Decorator
  delegate_all

  def title
    (tag = object.canonical_expression || object.tags.first) ? tag.name : '** no tag **'
  end

end