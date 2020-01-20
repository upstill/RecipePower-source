module RecipePagesHelper
  def do_recipe_pages_panel pane=:recipe_pages # do_panel
    # return render('notifs/panel', sections: sections, as_alert: true, wide: true)
    return render('recipe_pages/panel', pane_for: pane, wide: true)
  end
end
