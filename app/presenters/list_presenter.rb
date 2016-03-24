class ListPresenter < CollectiblePresenter
  def card_subhead_content
    "A list by #{@object.owner.handle}."
  end

  def card_aspect which
    label = nil
    content =
        case which
          when :description
            @object.description
          when :notes
            @object.notes
          when :created_by
            @object.owner.handle
        end
    [ label, content ]
  end

  # Provide a list of aspects for display in the entity's panel, suitable for passing to card_aspect
  def card_aspects which_column=nil
    [ :created_by, :description, :notes ]
  end
end
