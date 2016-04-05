class ListPresenter < CollectiblePresenter
  def card_subhead_content
    "A list by #{@object.owner.handle}."
  end

  def card_aspect which
    label = nil
    content =
    case which
      when :created_by
        label = 'as compiled by'
        h.labelled_avatar @object.owner.decorate
      when :description
        label = ''
        @object.description
      when :tags
        present_field_wrapped 'tags'
      when :notes
        label = 'description'
        @object.notes
      else
        return super
    end
    [ label, content ]
  end

  # Provide a list of aspects for display in the entity's panel, suitable for passing to card_aspect
  def card_aspects which_column=nil
    [ :created_by, :description, :tags, :notes ]
  end
end
