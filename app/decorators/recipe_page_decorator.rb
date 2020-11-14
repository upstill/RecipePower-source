class RecipePageDecorator < ModelDecorator
  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def title
    'Recipe Page'
  end

  def regenerate_dependent_content
    # Detect when the content of the recipe page might have changed (ie., when the page_ref has changed)
    either = @object.site.grammar_mods_changed?
    either ||= @object.page_ref.decorate.regenerate_dependent_content
    @object.refresh_attributes :content if either
    either
  end
end
