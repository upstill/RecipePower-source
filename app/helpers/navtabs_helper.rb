module NavtabsHelper

  # Define one element of the navbar. Could be a
  # -- simple label (no go_path and no block given)
  # -- link (valid go_path but no block)
  # -- Full-bore dropdown menu (block given), with or without a link at the top (go_path given or not)
  # 'mode' denotes what to produce, one of:
  #   :replacement -- return the portion of the menu that's replaced when elements have changed
  #   :trigger -- the relevant menu, but with a trigger for defining the above in a separate request
  #   :full -- the entire menu: no trigger, no replacement
  def navtab which, menu_label, go_path, mode, booger=nil
    NestedBenchmark.measure ">> construct #{which} navtab" do
      options={}
      class_str = 'master-navtab'
      if which == (@active_menu || response_service.active_menu)
        class_str << ' active'
      end
      # return content_tag( :li, link_to(menu_label, '#', class: 'dropdown-toggle'), class: class_str, id: navtab_id(which))

      # The block should produce an array of menu items (links, etc.)
      itemlist =
          if mode == :trigger
            # Instead of generating the items now, leave a trigger for getting them later
            # id: navmenu_id(which)
          elsif block_given?
            menu_items = NestedBenchmark.measure '>>>> generate menu items' do
              yield
            end
            if menu_items.present?
              NestedBenchmark.measure '>>>> generate item list' do
                menu_label << content_tag(:span, '', class: 'caret')
                content_tag :ul,
                            menu_items.collect { |item| content_tag :li, item }.join("\n").html_safe,
                            class: 'dropdown-menu scrollable-menu',
                            id: navmenu_id(which)
              end
            end
          end

      if mode == :replacement
        itemlist
      else
        NestedBenchmark.measure '>>>> rolling up menu' do
          header = link_to_submit menu_label.html_safe,
                                  (go_path.present? ? go_path : 'javascript:void(0);'),
                                  class: "dropdown-toggle #{options[:class]}",
                                  mode: :partial,
                                  data: {toggle: 'dropdown'},
                                  title: "Go To #{menu_label}"

          content = content_tag(:div, header+itemlist, class: 'dropdown')
          content += booger if booger
          content_tag :li,
                      content,
                      id: navtab_id(which),
                      class: class_str
        end
      end
    end
  end

  def collections_navtab mode = :full
    navtab :collections, 'Collections', collection_user_path(current_user_or_guest), mode do
      [
          link_to_submit('My Collection', collection_user_path(current_user_or_guest)),
          link_to_submit('Cookmarks', collection_user_path(current_user_or_guest, result_type: 'cookmarks'), class: 'submenu'),
          link_to_submit('Treasuries', collection_user_path(current_user_or_guest, result_type: 'lists'), class: 'submenu'),
          link_to_submit('Feeds', collection_user_path(current_user_or_guest, result_type: 'feeds'), class: 'submenu'),
          link_to_submit('Friends', collection_user_path(current_user_or_guest, result_type: 'friends'), class: 'submenu'),
          # link_to_submit('Recently Viewed', user_recent_path(current_user_or_guest_id)),
          link_to_submit('The RecipePower Collection', search_path()),
          '<hr class="menu">'.html_safe,
          link_to_submit('Add to Collection...', new_page_ref_path, :mode => :modal),
          # link_to_submit('New PageRef...', new_page_ref_path, :mode => :modal),
          link_to_submit('Install Cookmark Button...', cookmark_path, :mode => :modal)
      ]
    end
  end

  def friends_navtab mode = :full
    friends = NestedBenchmark.measure '>> query friends' do
      current_user_or_guest.followees.limit 10
    end
    navtab :friends, 'Cookmates', users_path(:select => :followees), mode do
      friends.collect { |u|
        link_to_submit u.handle, user_path(u), id: dom_id(u)
      } + [
          '<hr class="menu">'.html_safe,
          link_to_dialog('Invite Someone to RecipePower!', new_user_invitation_path),
          link_to_submit('Browse for friends...', users_path(:select => :relevant))
      ]
    end
  end

  def my_lists_navtab mode = :full
    lids =
    NestedBenchmark.measure '>> query lists' do
      # List.joins(:name_tag).where(owner_id: current_user_or_guest.id).pluck :id, :'tags.name'
      arr1 = List.where(owner_id: current_user_or_guest.id).limit(16).pluck :id, :name_tag_id
      arr2 = Tag.where( id: arr1.map(&:last)).pluck :id, :name
      # Replace the tag ids in the first array with the corresponding name from the second
      arr1.map { |elem| [elem.first, arr2.find { |elem2| elem2.first == elem.last}.last ] }
    end
    navtab :my_lists, 'Treasuries', lists_path(access: 'owned'), mode do
      NestedBenchmark.measure('...collect list links') {
        lids.collect { |lid|
          link_to_submit lid.last, list_path(lid.first), id: "list_#{lid.first}"
        }
      } +
          NestedBenchmark.measure('...add final links') do
            [
                '<hr class=\'menu\'>'.html_safe,
                link_to_dialog('Start a Treasury...', new_list_path, class: 'transient'),
                link_to_submit('Hunt for Treasuries...', lists_path(item_mode: 'table'))
            ]
          end
    end
  end

=begin
  def other_lists_navtab mode = :full
    navtab :other_lists, 'More Treasuries', lists_path(access: 'collected'), mode do
      list_set = current_user_or_guest.decorate.collection_lists.take(16)
      if list_set.count < 16
        # Try adding the lists owned by friends
        current_user_or_guest.followees.each { |friend|
          list_set = (list_set +
              friend.decorate.owned_lists(current_user_or_guest).includes(:name_tag).to_a.
                  keep_if { |l| l.name != 'Keepers' && l.name != 'To Try' && l.name != 'Now Cooking' }
          ).uniq
          break if list_set.count >= 16
        }
      end
      list_set.collect { |l|
        link_to_submit l.name, list_path(l), id: dom_id(l)
      } + [
          '<hr class="menu">'.html_safe,
          link_to_dialog('Start a new Treasury...', new_list_path),
          link_to_submit('Hunt for Treasuries...', lists_path(item_mode: 'table'))
      ]
    end
  end
=end

  def feeds_navtab mode = :full
    navtab :feeds, 'Feeds', feeds_path(access: 'collected'), mode do
      feed_set =
          NestedBenchmark.measure 'query (old)' do
            current_user_or_guest.collection_scope(entity_type: 'Feed').
                joins(:feeds).
                where('rcprefs.entity_id = feeds.id and feeds.approved = true').
                order('feeds.last_post_date DESC').
                limit(16).
                includes(:entity).
                map(&:entity).
                compact
          end
=begin
      data = NestedBenchmark.measure 'query (new)' do
        fids = current_user_or_guest.collection_scope(entity_type: 'Feed').pluck :entity_id
        Feed.where(id: fids, approved: true).
            order(:last_post_date => 'DESC').
            limit(16).
            pluck(:id, :title)
      end
=end
      # feed_set = current_user_or_guest.collection_scope(entity_type: 'Feed', limit: 16, sort_by: :viewed).includes(:entity).map(&:entity).compact
=begin
      if feed_set.count < 16
        # Try adding the lists owned by friends
        current_user_or_guest.followees.each { |friend|
          feed_set = (feed_set + friend.feeds).uniq
          break if feed_set.count >= 16
        }
      end
=end
      result = NestedBenchmark.measure 'collect feed links (old)' do
        feed_set.collect { |f|
          link_to_submit truncate(f.title, length: 30), feed_path(f), id: dom_id(f)
        }
      end
=begin
      NestedBenchmark.measure 'collect feed links (new)' do
        data.collect { |datum|
          link_to_submit truncate(datum.last, length: 30), feed_path(datum.first), id: "feeds_#{datum.first}"
        }
      end
=end
      result + [
          '<hr class="menu">'.html_safe,
          link_to_dialog('Add a Feed...', new_feed_path),
          link_to_submit('Browse for More Feeds...', feeds_path(item_mode: 'table', access: (response_service.admin_view? ? 'all' : 'approved')))
      ]
    end
  end

=begin
  def news_navtab mode = :full
    navtab :news, 'News', "/users/#{current_user_or_guest_id}/news", mode
  end

  def more_navtab mode = :full
    navtab :more, 'More', "/users/#{current_user_or_guest_id}/biglist", mode
  end
=end

  def home_navtab mode = :full
    # Include a placeholder for the notifications, which will be rendered in a subsequent call
    notifications = content_tag :div, ''.html_safe, class: 'notification_wrapper' # render_notifications_of current_user
    navtab :home,
           content_tag(:span, "#{current_user.handle}&nbsp;".html_safe, class: 'user-name')+
               content_tag(:span, '', class: 'measuring-spoons'),
           user_path(current_user, :mode => :partial),
           mode, notifications.html_safe do
      item_list = [
          link_to_dialog('Sign-in Services', authentications_path, class: 'transient'),
          link_to_dialog('Profile', users_profile_path),
          link_to_dialog('Invite', new_user_invitation_path, class: 'transient'),
          link_to_submit('Sign Out', destroy_user_session_path, :method => 'delete')
      ].compact
      if permitted_to? :admin, :pages
        if response_service.admin_view?
          item_list += [
              '<hr class="menu">'.html_safe,
              link_to_submit('Admin View Off', admin_toggle_path(on: false), class: 'transient'),
              link_to('Admin', admin_path),
              # link_to_dialog('Upload Picture', getpic_user_path(current_user), :mode => :modal),
              # link_to('Address Bar Magic', '#', onclick: "RP.getgo('#{home_path}', 'http://local.recipepower.com:3000/bar.html##{bookmarklet_script}')"),
              # link_to('Bookmark Magic', '#', onclick: "RP.bm('Cookmark', '#{bookmarklet_script}')"),
              # link_to('Stream Test', '#', onclick: 'RP.stream.buffer_test();'),
              # (link_to_submit('Page', current_user) if current_user),
              # (link_to_dialog('Modal', current_user) if current_user),
              link_to_submit('Review Pending Sites', sites_path(approved: 'nil')),
              link_to_submit('Review Hidden Sites', sites_path(approved: false)),
              link_to_submit('Review Free Tags', tags_path(tagtype: 0)),
              link_to_submit('Review Pending Feeds', feeds_path(approved: 'nil')),
              link_to_dialog('Scrape', scraper_new_path),
              link_to_dialog('New Reference', new_page_ref_path)
          # (button_to_submit('Initialize DB for scraping', scraper_init_path, :method => :post) if Rails.env.development? || Rails.env.staging?)
          ].compact
        else
          item_list += [
              '<hr class="menu">'.html_safe,
              link_to_submit('Admin View On', admin_toggle_path(on: true), class: 'transient')
          ]
        end
      end
      item_list
    end
  end

  # Package the navtab up to be replaced via AJAX
  def navmenu_replacement which
    ["ul##{navmenu_id(which)}", method(:"#{which}_navtab").call(:replacement)]
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


