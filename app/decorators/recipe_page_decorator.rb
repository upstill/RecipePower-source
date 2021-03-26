class RecipePageDecorator < CollectibleDecorator
  delegate_all

  def human_name plural=false, capitalize=true
    'Recipe Set'
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def regenerate_dependent_content
    # Detect when the content of the recipe page might have changed (ie., when the page_ref has changed)
    either = page_ref.decorate.regenerate_dependent_content
    either ||= site.grammar_mods[:rp_recipelist] != site.grammar_mods_was[:rp_recipelist]&.deep_symbolize_keys
    @object.refresh_attributes :content if either
    either
  end
end
