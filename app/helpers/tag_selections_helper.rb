module TagSelectionsHelper

  def tag_selection_form tag_selection
    with_format("html") { render "form", tag_selection: tag_selection }
  end

  def tag_selection_form_replacement tag_selection
    [ 'form.new_tag_selection', tag_selection_form(tag_selection)]
  end

=begin
            <div class="control-group">
              <label class="string optional">Tag(s)<br><span class="locked-tags"><%= decorator.locked_untyped_culinaryterm_tags.map(&:name).join ' | ' %></span></label>
              <input id="<%= decorator.element_id :tagging_user_id %>" name="<%= decorator.field_name :tagging_user_id %>" type="hidden" value="<%= decorator.tagging_user_id %>">
              <input type="text"
                     class="token-input-field-pending"
                     id="editable_untyped_culinaryterm_tag_tokens"
                     name="<%= decorator.field_name :editable_untyped_culinaryterm_tag_tokens %>"
                     rows="2"
                     size="30"
                     placeholder="Tags"
                     data-tagtype_x="7"
                     data-pre="<%= decorator.editable_untyped_culinaryterm_tags.map(&:attributes).to_json %>"/>
            </div>
            <div class="control-group">
              <label class="string optional"><%= label %>(s)<br><span class="locked-tags"><%= locked_tags %></span></label>
              <input id="<%= decorator.element_id :tagging_user_id %>" name="<%= decorator.field_name :tagging_user_id %>" type="hidden" value="<%= decorator.tagging_user_id %>">
              <input type="text"
                     class="token-input-field-pending"
                     id="<%= tokens_id %>"
                     name="<%= decorator.field_name tokens_id %>"
                     rows="2"
                     size="30"
                     placeholder="<%= label.pluralize %>"
                     data-tagtype="7"
                     data-pre="<%= data_pre %>"/>
            </div>
=end
  def tagging_fields decorator
    results =
        decorator.individual_tagtypes.collect do |type|
          dc = type.to_s.downcase
          locked_tags = decorator.send "locked_#{dc}_tags"
          editable_tags = decorator.send "editable_#{dc}_tags"
          render('tags/tag_controls',
                 decorator: decorator,
                 label: decorator.send("#{dc}_tags_label"),
                 tokens_id: "editable_#{dc}_tag_tokens",
                 tagtypes: decorator.send("#{dc}_tag_types"),
                 locked_tags: locked_tags.map(&:name).join(' | '),
                 data_pre: editable_tags.map(&:attributes).to_json)
        end
    return results[0] if results.count == 1
    col1 = ''.html_safe
    col2 = ''.html_safe
    # If more than one, divide it into two columns
    while result = results.shift do
      col1 << result
      col2 << results.shift || ''.html_safe
    end
    content_tag(:div,
                content_tag(:div, col1, class: 'col-md-6') + content_tag(:div, col2, class: 'col-md-6'),
                class: 'row')
  end

end
