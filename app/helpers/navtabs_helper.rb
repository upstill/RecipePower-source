module NavtabsHelper

  def dropdown_menu label, items, id, link_options={}
    itemlist =
        content_tag :ul,
                    items.collect { |item| content_tag :li, item }.join("\n").html_safe,
                    class: "dropdown-menu",
                    id: id
    label << content_tag(:span, "", class: "caret")

    content = navlink label, '', true, link_options
    content_tag :li,
                content + itemlist,
                id: id,
                class: 'dropdown'

  end

  # Define one element of the navbar. Could be a
  # -- simple label (no go_path and no block given)
  # -- link (valid go_path but no block)
  # -- Full-bore dropdown menu (block given), with or without a link at the top (go_path given or not)
  def navtab which, menu_label, go_path=nil, menu_only = false
    options={}
    class_str = "master-navtab"
    if which == (@active_menu || response_service.active_menu)
      class_str << " active"
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

    header = navlink menu_label.html_safe, go_path, true, options
    content_tag :li,
                "#{header} #{itemlist}".html_safe,
                id: navtab_id(which),
                class: class_str
  end

  # Declare one navlink with appropriate format and query parameters
  def navlink label, path, is_menu_header=false, options={}
    if is_menu_header.is_a? Hash
      is_menu_header, options = false, is_menu_header
    end
    # The menu headers may or may not have links, but they do have dropdown menus
    if is_menu_header
      options[:class] = "dropdown-toggle #{options[:class]}"
      options[:data] ||= {}
      options[:data][:toggle] = "dropdown"
    end
    link_to_submit label, path, options  # defaults to partial
  end

  def collections_navtab menu_only = false
    navtab :collections, "Collections", collection_user_path(current_user_or_guest), menu_only do
      [
          navlink("My Collection", collection_user_path(current_user_or_guest)),
          navlink("Recently Viewed", user_recent_path(current_user_or_guest_id)),
          navlink("Everything in RecipePower", user_biglist_path(current_user_or_guest)),
          "<hr class='menu'>".html_safe,
          navlink("Add to Collection", new_recipe_path, :mode => :modal)
      ]
    end
  end

  def friends_navtab menu_only = false
    navtab :friends, "Cookmates", users_path(:select => :followees), menu_only do
      current_user_or_guest.followees[0..10].collect { |u|
        navlink u.handle, user_path(u), id: dom_id(u)
      } + [
          "<hr class='menu'>".html_safe,
          navlink("Get another friend...", users_path(:select => :relevant))
      ]
    end
  end

  def my_lists_navtab menu_only = false
    navtab :my_lists, 'Treasuries', lists_path(access: "owned"), menu_only do
      current_user_or_guest.owned_lists[0..16].collect { |l|
        navlink l.name, list_path(l), id: dom_id(l)
      } + [
          "<hr class='menu'>".html_safe,
          navlink("Start a Treasury...", new_list_path, mode: :modal, class: "transient")
      ]
    end
  end

  def other_lists_navtab menu_only = false
    navtab :other_lists, "More Treasuries", lists_path(access: "collected"), menu_only do
      list_set = current_user_or_guest.collection_pointers.where(entity_type: "List").
          joins("INNER JOIN lists ON lists.id = rcprefs.entity_id").where("lists.owner_id != #{current_user_or_guest.id}").
          limit(16).
          map(&:entity)
      if list_set.count < 16
        # Try adding the lists owned by friends
        current_user_or_guest.followees.each { |friend|
          list_set = (list_set +
              friend.owned_lists.where.not(availability: 2).to_a.
                  keep_if { |l| l.name != "Keepers" && l.name != "To Try" && l.name != "Now Cooking" }
          ).uniq
          break if list_set.count >= 16
        }
      end
      list_set.collect { |l|
        navlink l.name, list_path(l), id: dom_id(l)
      } + [
          navlink("Start a new Treasury...", new_list_path(mode: 'modal')),
          "<hr class='menu'>".html_safe,
          navlink("Start a new Treasury...", new_list_path(mode: 'modal')),
          navlink("Hunt for Treasuries...", lists_path(item_mode: 'table'))
      ]
    end
  end

  def feeds_navtab menu_only = false
    navtab :feeds, "Feeds", feeds_path(access: "collected"), menu_only do
      feed_set = current_user_or_guest.collection_scope(entity_type: "Feed", limit: 16, sort_by: :viewed).map(&:entity)
      if feed_set.count < 16
        # Try adding the lists owned by friends
        current_user_or_guest.followees.each { |friend|
          feed_set = (feed_set + friend.feeds).uniq
          break if feed_set.count >= 16
        }
      end
      result = feed_set.collect { |f|
        navlink truncate(f.title, length: 30), feed_path(f), id: dom_id(f)
      }
      result + [
          "<hr class='menu'>".html_safe,
          navlink("Add a Feed...", new_feed_path(mode: 'modal')),
          navlink("Browse for More Feeds...", feeds_path(item_mode: 'table', access: (response_service.admin_view? ? "all" : "approved")))
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
           content_tag(:span, "#{current_user.handle}&nbsp;".html_safe, class: "user-name")+
               content_tag(:span, '', class: 'measuring-spoons'),
           user_path(current_user, :mode => :partial),
           menu_only do
      item_list = [
          # navlink( "Profile", users_profile_path( section: "profile" ), :mode => :modal),
          navlink('Sign-in Services', authentications_path, :mode => :modal, class: "transient"),
          navlink("Profile", users_profile_path, :mode => :modal),
          navlink("Invite", new_user_invitation_path, :mode => :modal, class: "transient"),
          navlink("Sign Out", destroy_user_session_path, :method => "delete")
      ].compact
      if permitted_to? :admin, :pages
        if response_service.admin_view?
          item_list += [
            "<hr class='menu'>".html_safe,
            link_to_submit( "Admin View Off", admin_toggle_path(on: false), class: "transient"),
            link_to_submit("Add Cookmark", new_recipe_path, :mode => :modal, class: "transient"),
            link_to("Admin", admin_path),
            link_to_submit("Upload Picture", getpic_user_path(current_user), :mode => :modal),
            link_to("Address Bar Magic", "#", onclick: "RP.getgo('#{home_path}', 'http://local.recipepower.com:3000/bar.html##{bookmarklet_script}')"),
            link_to("Bookmark Magic", "#", onclick: "RP.bm('Cookmark', '#{bookmarklet_script}')"),
            link_to("Stream Test", "#", onclick: "RP.stream.buffer_test();"),
            (link_to_submit("Page", current_user, :format => :json) if current_user),
            (link_to_submit("Modal", current_user, :format => :json, :mode => :modal) if current_user),
            link_to_submit("Sites", sites_path, :format => :json),
            link_to_submit("Tags", tags_path, :format => :json)
          ].compact
        else
          item_list += [
              "<hr class='menu'>".html_safe,
              link_to_submit("Admin View On", admin_toggle_path(on: true), class: "transient")
          ]
        end
      end
      item_list
    end
  end

  # Package the navtab up to be replaced via AJAX
  def navmenu_replacement which
    [ "ul##{navmenu_id(which)}", method(:"#{which}_navtab").call(true) ]
  end

  def friends_navtab_replacement
    [ 'ul#friends-navmenu', friends_navtab(true) ]
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

  def checkbox_menu_item_label label, check=false
    content_tag :label, "<input type='checkbox' class='submit' #{'checked=true' if check}>&nbsp;#{label}".html_safe
  end

  end


