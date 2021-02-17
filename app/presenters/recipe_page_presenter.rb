class RecipePagePresenter < BasePresenter

  def content_suggestion
    dlg = link_to_submit 'here',
                         edit_recipe_page_path(@object, topics: :page_recipes),
                         mode: :modal,
                         title: 'Edit Trimmers'
    cs = <<EOF
          This page is supposed to have multiple recipes.<br>
          Click #{edit_trimmers_button @object, 'here'} to stipulate how to demarcate them algorithmically.<br>
          Click #{dlg} to select them directly.
EOF
    cs.html_safe
  end

  # When a Gleaning is updated, what types of item get replaced?
  def update_items
    [ :content ]
  end
end
