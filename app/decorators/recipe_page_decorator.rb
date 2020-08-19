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

  def refresh_content variant=nil
    @object.content = nil
    @object.bkg_launch
    @object.bkg_land
    @object.save
  end
end
