module StreamHelper

  def stream_table headers
    render "shared/stream_results_table", headers: headers
  end

  def stream_element_class etype
    "stream-#{etype}"
  end

  # Use a partial to generate a stream header, and surround it with a 'stream-header' div
  def stream_element etype, headerpartial=nil
    # Define a default partial as needed
    headerpartial ||= "shared/stream_#{etype}" unless block_given?
    if headerpartial
      content = with_format("html") { render headerpartial }
    else # If no headerpartial provided, expect there to be a code block to produce the content
      content = with_format("html") { yield }
    end
    content_tag :div, content, class: stream_element_class(etype)
  end

  # Generate a JSON item for replacing the stream header
  def stream_element_replacement etype, headerpartial=nil
    content = block_given? ?
      stream_element( etype, headerpartial) { yield } :
      stream_element(etype, headerpartial)
    ["."+stream_element_class(etype), content ]
  end

  def stream_filter_field presenter, options={}
    options[:data] ||= {}
    options[:data][:hint] ||= "Narrow down the list"
    tag_arr = @querytags.map(&:attributes).collect { |attr| { id: attr["id"], name: attr["name"] } }
    options[:data][:pre] ||= tag_arr.to_json
    # options[:data][:token_limit] = 1 unless is_plural
    options[:data][:"min-chars"] ||= 2
    options[:data][:query] = "tagtypes=#{presenter.tagtypes.map(&:to_s).join(',')}" if presenter.tagtypes
    options[:class] = "token-input-field-pending #{options[:class]}" # The token-input-field-pending class triggers tokenInput
    options[:onload] = "RP.tagger.onload(evt);"
    text_field_tag "querytags", @querytags.map(&:id).join(','), options
  end

  # Render an element of a collection, depending on its class
  # NB The view is derived from the class of the element, NOT from the current controller
  def render_stream_item element, partialname
    # Prepend the partialname with the view directory name if it doesn't already have one
    partialname = "#{element.class.to_s.pluralize.downcase}/#{partialname}" unless partialname.match /\//
    render partial: partialname, locals: { :item => element }
  end

  # Provide one element of a dropdown menu for a selection
  def stream_menu_item label, path, id
    link_to_submit label, assert_query(path, partial: true), id: id
  end

  # Declare the dropdown for a particular class of collection
  def stream_dropdown which
    menu_items = []
    if current_user
      menu_items =
      case which
        when :personal
          menu_path = "/users/#{current_user_or_guest_id}/collection.json?partial=true"
          current_user.lists.collect { |l| stream_menu_item(l.name, list_path(l, format: :json), dom_id(l)) }
        when :friends
          current_user.followees.collect { |u| stream_menu_item(u.handle, user_friends_collection_path(u), dom_id(u)) }
        when :public
          [] # current_user.private_subscriptions.collect { |l| stream_menu_item(l.name, list_path(l), dom_id(l)) }
      end
    end
    menu_items << %q{<hr style="margin:5px">}
    active = false # ?? XXX @browser.selected.classed_as == which
    case which
      when :personal  # Add "All My Cookmarks", "Recently Viewed" and "New Collection..." items
#        collection_selection = stream_menu_item("My Collection", user_private_collection_path(current_user), dom_id(current_user_or_guest))
        menu_items << link_to_submit("Recently Viewed", "/users/#{current_user_or_guest_id}/recent.json?partial=true") # ( @browser.find_by_id "RcpBrowserElementRecent"  )
        menu_items << link_to_modal("New Personal List...", new_list_path(modal: true))
      when :friends  # Add "All Friends' Cookmarks" and "Make a Friend..." items
        menu_items << link_to("Make a Friend...", @browser.find_by_id("RcpBrowserCompositeFriends").add_path)
      when :public   # Add "The Master Collection", and "Another Collection..." items
        # menu_items << collection_selection( @browser.find_by_id menu_css_id )
        menu_items << link_to("New Public List...", new_list_path( modal: true ))
    end
    menu_list = "<li>" + menu_items.join('</li><li>') + "</li>"
    menu_label = %Q{#{which.to_s.capitalize}<span class="caret"><span>}.html_safe
    content_tag :li,
                link_to_submit( menu_label, menu_path, class: "dropdown-toggle", data: { toggle: "dropdown" } )+
                # collection_selection(nil, menu_label, menu_css_id )+
                # link_to( menu_label, menu_path, class: "collection_selection", id: id ) +
                    content_tag(:ul, menu_list.html_safe, class: "dropdown-menu"),
                class: "dropdown"+(active ? " active" : "")
  end

end
