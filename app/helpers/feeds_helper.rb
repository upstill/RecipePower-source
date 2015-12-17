module FeedsHelper

  def feed_status_report feed, querytags
    tag_query = querytags.collect { |tag| tag.id > 0 ? tag.id.to_s : tag.name }.join(',')
    params = tag_query.blank? ? {} : { querytags: tag_query }
    url = refresh_feed_path(feed, params)

    if feed.status == 'ready'
      label = 'Check for Updates'
    else
      status = "Update #{feed.status}. "
      label = 'Try Again'
    end
    link = link_to_submit label, url, feed_wait_msg(feed, true).merge(button_size: 'sm')
    content_tag :span,
                "Last updated #{time_ago_in_words feed.updated_at} ago. #{status}#{link}".html_safe,
                class: 'feed-status-report'
  end

  def feed_wait_msg feed, force=false
    wait_msg = "Hang on, we're contacting #{feed.site.name} for updates. This could take a minute." if force || feed.due_for_update
    wait_msg ? { 'wait-msg' => wait_msg } : {}
  end

  def feed_update_button feed
    link_to_submit 'Update', refresh_feed_path(feed), feed_wait_msg(feed).merge(:button_size => 'xs')
  end

  def feed_entries_report feed
    case nmatches = feed.feed_entries.size
      when 0
        'No&nbsp;entries. '.html_safe
      when 1
        'One&nbsp;entry, '.html_safe
      else
        "#{nmatches}&nbsp;entries, ".html_safe
    end
  end

  # Summarize the number of entries/latest entry for a feed
  def feed_status_summary feed
    feed_entries_status(feed) + feed_update_button(feed)
  end

  def feed_status_report_replacement feed, querytags
    [ 'span.feed-status-report', feed_status_report(feed, querytags) ]
  end

  def feed_entries_status feed
    result = feed_entries_report feed
    if (feed.feed_entries.size > 0) && feed.last_post_date
      time_report = (feed.last_post_date.today?) ? 'Today' : "#{time_ago_in_words feed.last_post_date} ago"
      result = result + 'latest '.html_safe if feed.feed_entries.size > 1
      result + "posted #{time_report}.".html_safe
    else
      result
    end
  end

  def feed_subscribe_button item, options={}
    if item.collectible_collected? current_user_or_guest_id
      label, path = 'Unsubscribe', collect_feed_path(item, in_collection: false)
    else
      return if options[:unsub_only]
      label, path = 'Subscribe', collect_feed_path(item)
    end
    link_to_submit label, path, { method: :post }.merge(options)
  end

  def feed_collectible_buttons decorator, options={}
    collectible_buttons_panel @decorator, options do 
      feed_subscribe_button @feed, options
    end
  end

  def feed_buttons_replacement decorator, options={}
    [ "div.collectible-buttons##{dom_id decorator}", feed_collectible_buttons(decorator, options) ]
  end

  def feed_approval feed
    str = case feed.approved
            when true
              'Approved '
            when false
              'Blocked '
            else
              ''
          end
          # NB: feeds can have no approval status, in which case both buttons should show
          str << link_to_submit('Approve',
                                approve_feed_path(feed, approve: 'Y'),
                                button_style: 'success',
                                button_size: 'xs',
                                method: 'POST'
          ) unless feed.approved == true
          str << link_to_submit('Block',
                                approve_feed_path(feed, approve: 'N'),
                                button_style: 'success',
                                button_size: 'xs',
                                method: 'POST'
          ) unless feed.approved == false
    content_tag :span, str.html_safe, :id => dom_id(feed)
  end

  def feed_approval_replacement feed
    [ "span##{dom_id feed}", feed_approval(feed) ]
  end

  def feed_homelink feed, options={}
    title = feed.title
    title = title.truncate(options[:truncate]) if options[:truncate]
    (data = (options[:data] || {}))[:report] = polymorphic_path [:touch, feed]
    klass = "#{options[:class]} entity feed"
    # Default submission is for #owned action
    action = options[:action] || :owned
    link_to_submit feed.title,
                   polymorphic_path([action, feed]),
                   {mode: :partial}.merge(options).merge(data: data, class: klass).except(:action, :truncate)
  end

end
