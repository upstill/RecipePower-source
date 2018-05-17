class ReferentDecorator < ModelDecorator
  include Templateer
  include DialogPanes
  delegate_all

  def title
    (tag = object.expression) ? tag.name : '** no tag **'
  end

  def human_name plural=false, capitalize=true
    object.class.to_s.sub /Referent/, ''
  end
end
