module TagSelectionsHelper

  def tag_selection_form tag_selection
    with_format("html") { render "form", tag_selection: tag_selection }
  end

  def tag_selection_form_replacement tag_selection
    [ 'form.new_tag_selection', tag_selection_form(tag_selection)]
  end
end
