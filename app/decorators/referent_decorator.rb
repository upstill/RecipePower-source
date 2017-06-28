class ReferentDecorator < ModelDecorator
  include Templateer
  delegate_all

  def title
    (tag = object.canonical_expression || object.tags.first) ? tag.name : '** no tag **'
  end

end
