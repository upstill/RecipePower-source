module NavtabsHelper

  # Define one element of the navbar. Could be a
  # -- simple label (no go_path and no block given)
  # -- link (valid go_path but no block)
  # -- Full-bore dropdown menu (block given), with or without a link at the top (go_path given or not)
  def navtab which, menu_label, go_path=nil
    options={}
    id = navtab_id which  # id used for the menu item
    class_str = "master-navtab"
    if which == (@active_menu || response_service.active_menu)
      class_str << " active"
    else
      options[:style] = "color: #999;"
    end

    # The block should produce an array of menu items (links, etc.)
    if block_given? && (menu_items = yield) && !menu_items.empty?
      itemlist =
          content_tag :ul,
                      menu_items.collect { |item| content_tag :li, item }.join("\n").html_safe,
                      class: "dropdown-menu"
      menu_label << content_tag(:span, "", class: "caret")
      class_str << " dropdown"
    end

    content = navlink menu_label.html_safe, go_path, true, options

    content_tag :li,
                "#{content} #{itemlist}".html_safe,
                id: id,
                class: class_str
  end

  # Declare one navlink with appropriate format and query parameters
  def navlink label, path_or_options, is_menu_header=false, options={}
    if is_menu_header.is_a? Hash
      is_menu_header, options = false, is_menu_header
    end
    # The menu headers may or may not have links, but they do have dropdown menus
    if is_menu_header
      options[:class] = "dropdown-toggle #{options[:class]}"
      options[:data] ||= {}
      options[:data][:toggle] = "dropdown"
    end
    link_to_submit label, path_or_options, { :mode => :partial}.merge( options )  # defaults to partial
  end

  def collections_navtab
    navtab :collections, "Collections", "/users/#{current_user_or_guest_id}/collection" do
      [
          navlink("My Collection", "/users/#{@user.id}/collection"),
          navlink("Recently Viewed", "/users/#{@user.id}/recent"),
          navlink("Everything in RecipePower", "/users/#{@user.id}/biglist")
      ]
    end
  end

  def friends_navtab
    navtab :friends, "Friends", users_path do
      @user.followees[0..6].collect { |u|
        navlink u.handle, "/users/#{u.id}/collection", id: dom_id(u)
      } + [
          "<hr class='menu'>".html_safe,
          navlink("Make a Friend...", users_path(relevant: true))
      ]
    end
  end

  def lists_navtab
    navtab :lists, "Lists", lists_path do
      @user.subscriptions(:own)[0..16].collect { |l|
        navlink l.name, list_path(l), id: dom_id(l)
      } + [
          "<hr class='menu'>".html_safe,
          navlink("Browse for Lists...", lists_path),
          navlink("Start a List...", new_list_path, mode: :modal)
      ]
    end
  end

  def feeds_navtab
    navtab :feeds, "Feeds", feeds_path do
      result = @user.feeds[0..12].collect { |f|
        navlink truncate(f.title, length: 30), feed_path(f), id: dom_id(f)
      }
      result + [
          "<hr class='menu'>".html_safe,
          navlink("Browse for More Feeds...", feeds_path)
      ]
    end
  end

  def news_navtab
    navtab :news, "News", "/users/#{current_user_or_guest_id}/news"
  end
  
  def more_navtab
    navtab :more, "More", "/users/#{current_user_or_guest_id}/biglist"
  end

  def home_navtab
    navtab :home,
           content_tag(:b, "&nbsp;#{current_user.handle}&nbsp;".html_safe, class: "glyphicon glyphicon-home")+
               content_tag(:b, "", class: "glyphicon glyphicon-cog"),
           user_path(current_user) do
      item_list = [
          # navlink( "Profile", users_profile_path( section: "profile" ), :mode => :modal),
          navlink("Sign-in Services", authentications_path, :mode => :modal),
          navlink("Invite", new_user_invitation_path, :mode => :modal),
          navlink("Sign Out", destroy_user_session_path, :method => "delete")
      ]
      item_list += [
          "<hr class='menu'>".html_safe,
          link_to_submit("Add Cookmark", new_recipe_path, :mode => :modal),
          link_to("Admin", admin_path),
          link_to("Refresh Masonry", "#", onclick: "RP.collection.justify();"),
          link_to("Address Bar Magic", "#", onclick: "RP.getgo('#{home_path}', 'http://local.recipepower.com:3000/bar.html##{bookmarklet_script}')"),
          link_to("Bookmark Magic", "#", onclick: "RP.bm('Cookmark', '#{bookmarklet_script}')"),
          link_to("Stream Test", "#", onclick: "RP.stream.buffer_test();"),
          link_to_submit("Step 3", popup_path("starting_step3"), :mode => :modal)
      ] if permitted_to? :admin, :pages
      item_list
    end
  end

  # Package the navtab up to be replaced via AJAX
  def navtab_replacement which
    [ "li#{navtab_id(which)}", method(:"#{which}_navtab").call ]
  end

  protected
  # The CSS ID of the navtab
  def navtab_id which
    "#{which}-navtab"
  end
end


