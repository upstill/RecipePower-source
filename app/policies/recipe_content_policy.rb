class RecipeContentPolicy < RecipePolicy

  def annotate?
    @user&.is_editor?
  end

  def tag?
    @user&.is_editor?
  end

end











