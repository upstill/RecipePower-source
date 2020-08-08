class RecipePagePresenter < BasePresenter

  def html_content variant=nil
    @object.content
  end
end