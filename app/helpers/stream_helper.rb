module StreamHelper

  def stream_table headers
    render "shared/stream_table", headers: headers
  end

  def stream_masonry
    render "shared/stream_masonry"
  end

  def stream_items
    render "shared/stream_items"
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

  # Leave a link for stream firing
  def stream_link path, options={}
    options[:onclick] = 'RP.stream.go(event);'
    options[:data] = {} unless options[:data]
    options[:data][:path] = path
    options[:data][:container_selector] = response_service.container_selector
    link_to "Click to load", "#", options
  end

  # Render an element of a collection, depending on its class
  # NB The view is derived from the class of the element, NOT from the current controller
  def render_stream_item element, partialname
    view = element.class.to_s.pluralize.downcase
    render partial: "#{view}/#{partialname}", locals: { :item => element }
=begin
    case element
      when Recipe
        @recipe = element
        @recipe.current_user = @user.id
        content_tag( :div,
                     render("shared/recipe_grid"),
                     class: "masonry-item" )
      when FeedEntry
        @feed_entry = element
        render "shared/feed_entry"
      when Fixnum
        "<p>#{element}</p>"
      else
        # References and Referents are subclassed, but we get the row view from the original class
        if element.is_a? Reference
          @reference = element
          render partial: "references/show_table_row", locals: { :reference => element }
        elsif element.is_a? Referent
          @referent = element
          render partial: "referents/show_table_row", locals: { :referent => element }
        else
          # Default is to set instance variable @<Klass> and render "<klass>s/<klass>"
          ename = element.class.to_s.downcase
          self.instance_variable_set("@"+ename, element)
          render partial: "#{ename.pluralize}/show_table_row", locals: { :item => element }
        end
    end
=end
  end

  # Provide one element of a dropdown menu for a selection
  def stream_menu_item label, path, id
    link_to label, path, id: id
  end

  # Declare the dropdown for a particular class of collection
  def stream_dropdown which
    menu_items = []
    if current_user
      menu_items =
      case which
        when :personal
          menu_path = "/users/#{current_user_or_guest_id}/collection"
          current_user.lists.collect { |l| stream_menu_item(l.name, list_path(l), dom_id(l)) }
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
        menu_items << link_to( "Recently Viewed", "/users/#{current_user_or_guest_id}/recent") # ( @browser.find_by_id "RcpBrowserElementRecent"  )
        menu_items << link_to_modal( "New Personal List...", new_list_path( modal: true ))
      when :friends  # Add "All Friends' Cookmarks" and "Make a Friend..." items
        menu_items << link_to("Make a Friend...", @browser.find_by_id("RcpBrowserCompositeFriends").add_path)
      when :public   # Add "The Master Collection", and "Another Collection..." items
        # menu_items << collection_selection( @browser.find_by_id menu_css_id )
        menu_items << link_to("New Public List...", new_list_path( modal: true ))
    end
    menu_list = "<li>" + menu_items.join('</li><li>') + "</li>"
    menu_label = %Q{#{which.to_s.capitalize}<span class="caret"><span>}.html_safe
    content_tag :li,
                link_to( menu_label, menu_path, class: "dropdown-toggle", data: { toggle: "dropdown" } )+
                # collection_selection(nil, menu_label, menu_css_id )+
                # link_to( menu_label, menu_path, class: "collection_selection", id: id ) +
                    content_tag(:ul, menu_list.html_safe, class: "dropdown-menu"),
                class: "dropdown"+(active ? " active" : "")
  end

end