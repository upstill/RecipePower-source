class ListPresenter < CollectiblePresenter

  # Lists don't have a ribbon on their card
  def ribbon
  end

  # Lists don't have a ribbon on their card
  def card_label
  end

  def card_subhead_content
    "A list by #{@object.owner.handle}."
  end

  def card_avatar_accompaniment
    if up = h.present(@object.owner&.decorate)
      if av = up.avatar
        card_aspect_enclosure :created_by, av, 'Compiled By'
      end
    end
  end

  def card_aspect which
    label = nil
    content =
    case which
      when :description
        label = ''
        @object.description
      when :tags
        present_field 'tags'
      when :notes
        label = ''
        @object.notes
      else
        return super
    end
    [ label, content ]
  end

  # Provide a list of aspects for display in the entity's panel, suitable for passing to card_aspect
  def card_aspects which_column=nil
    [ :description, :tags, :notes ]
  end
end
