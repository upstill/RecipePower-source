module NestedAttributesHelper
  def na_menu f, id, tag_selections
    field_data = data_to_add_fields f, :tag_selections, user_id: f.object.id
    tsids = tag_selections.map(&:tagset_id)
    optionset = Tagset.all.collect { |ts|
      content_tag :option,
                  ts.title,
                  {
                      value: ts.id,
                      style: ("display: none;" if tsids.include?(ts.id)),
                      data: {subs: {tagset_id: ts.id}}
                  }.compact
    }
    prompt = tag_selections.empty? ? "Pick One" : "Pick Another"
    hide = tag_selections.count == optionset.count # Don't show the menu if all options are already selected
    select_tag id,
               optionset.unshift(content_tag :option, prompt, value: 0).join.html_safe,
               {
                   value: 0,
                   data: field_data,
                   hidden: hide
               }.compact

  end
end