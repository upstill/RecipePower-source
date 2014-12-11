module NavtabsHelper

  # Define one element of the navbar. Could be a
  # -- simple label (no go_path and no block given)
  # -- link (valid go_path but no block)
  # -- Full-bore dropdown menu (block given), with or without a link at the top (go_path given or not)
  def navtab which, menu_label, go_path=nil, menu_only = false
    options={}
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
                      class: "dropdown-menu",
                      id: navmenu_id(which)
      menu_label << content_tag(:span, "", class: "caret")
      class_str << " dropdown"
    end

    return itemlist if menu_only

    content = navlink menu_label.html_safe, go_path, true, options
    content_tag :li,
                "#{content} #{itemlist}".html_safe,
                id: navtab_id(which),
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

  def collections_navtab menu_only = false
    navtab :collections, "Collections", "/users/#{current_user_or_guest_id}/collection", menu_only do
      [
          navlink("My Collection", "/users/#{@user.id}/collection"),
          navlink("Recently Viewed", "/users/#{@user.id}/recent"),
          navlink("Everything in RecipePower", "/users/#{@user.id}/biglist")
      ]
    end
  end

  def friends_navtab menu_only = false
    navtab :friends, "Friends", users_path, menu_only do
      @user.followees[0..6].collect { |u|
        navlink u.handle, "/users/#{u.id}/collection", id: dom_id(u)
      } + [
          "<hr class='menu'>".html_safe,
          navlink("Make a Friend...", users_path(relevant: true))
      ]
    end
  end

  def my_lists_navtab menu_only = false
    navtab :my_lists, "My Lists", lists_path(access: "owned"), menu_only do
      @user.owned_lists[0..16].collect { |l|
        navlink l.name, list_path(l), id: dom_id(l)
      } + [
          "<hr class='menu'>".html_safe,
          navlink("Start a List...", new_list_path, mode: :modal, class: "transient")
      ]
    end
  end

  def other_lists_navtab menu_only = false
    navtab :other_lists, "More Lists", lists_path(access: "collected"), menu_only do
      @user.rcprefs.where(entity_type: "List").
          joins("INNER JOIN lists ON lists.id = rcprefs.entity_id").where("lists.owner_id != #{@user.id}").
          limit(16).
          map(&:entity).collect { |l|
        navlink l.name, list_path(l), id: dom_id(l)
      } + [
          "<hr class='menu'>".html_safe,
          navlink("Browse for Lists...", lists_path),
      ]
    end
  end

  def feeds_navtab menu_only = false
    navtab :feeds, "Feeds", feeds_path(access: "collected"), menu_only do
      result = @user.collection_scope(entity_type: "Feed", limit: 16, sort_by: :viewed).map(&:entity).collect { |f|
        navlink truncate(f.title, length: 30), feed_path(f), id: dom_id(f)
      }
      result + [
          "<hr class='menu'>".html_safe,
          navlink("Browse for More Feeds...", feeds_path(access: (response_service.admin_view? ? "all" : "approved")))
      ]
    end
  end

  def news_navtab menu_only = false
    navtab :news, "News", "/users/#{current_user_or_guest_id}/news", menu_only
  end
  
  def more_navtab menu_only = false
    navtab :more, "More", "/users/#{current_user_or_guest_id}/biglist", menu_only
  end

  def home_navtab menu_only = false
    navtab :home,
           content_tag(:b, "&nbsp;#{current_user.handle}&nbsp;".html_safe, class: "glyphicon glyphicon-home")+
               content_tag(:b, "", class: "glyphicon glyphicon-cog"),
           user_path(current_user, :mode => :partial),
           menu_only do
      item_list = [
          # navlink( "Profile", users_profile_path( section: "profile" ), :mode => :modal),
          navlink("Sign-in Services", authentications_path, :mode => :modal, class: "transient"),
          navlink("Profile", users_profile_path, :mode => :page),
          navlink("Invite", new_user_invitation_path, :mode => :modal, class: "transient"),
          navlink("Sign Out", destroy_user_session_path, :method => "delete")
      ]
      if permitted_to? :admin, :pages
        if response_service.admin_view?
          item_list += [
            "<hr class='menu'>".html_safe,
            link_to_submit( "Admin View Off", admin_toggle_path(on: false), :mode => :partial, class: "transient"),
            link_to_submit("Add Cookmark", new_recipe_path, :mode => :modal, class: "transient"),
            link_to("Admin", admin_path),
            link_to_submit("Upload Picture", getpic_user_path(current_user), :mode => :modal),
            link_to("Refresh Masonry", "#", onclick: "RP.collection.justify();"),
            link_to("Address Bar Magic", "#", onclick: "RP.getgo('#{home_path}', 'http://local.recipepower.com:3000/bar.html##{bookmarklet_script}')"),
            link_to("Bookmark Magic", "#", onclick: "RP.bm('Cookmark', '#{bookmarklet_script}')"),
            link_to("Stream Test", "#", onclick: "RP.stream.buffer_test();"),
            link_to_submit("Step 3", popup_path("starting_step3"), :mode => :modal, class: "transient")
          ]
        else
          item_list += [
              "<hr class='menu'>".html_safe,
              link_to_submit("Admin View On", admin_toggle_path(on: true), :mode => :partial, class: "transient")
          ]
        end
      end
      item_list
    end
  end

  # Package the navtab up to be replaced via AJAX
  def navtab_replacement which
    [ "ul##{navmenu_id(which)}", method(:"#{which}_navtab").call(true) ]
  end

  protected

  # The CSS ID of the navtab
  def navtab_id which
    "#{which}-navtab"
  end

  # The CSS ID of the navmenu
  def navmenu_id which
    "#{which}-navmenu"
  end
end


