class ReferentDecorator < ModelDecorator
  include Templateer
  delegate_all

  def title
    (tag = object.expression) ? tag.name : '** no tag **'
  end

end
