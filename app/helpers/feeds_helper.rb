module FeedsHelper

  def feed_status_report feed, querytags
    tag_query = querytags.collect { |tag| tag.id > 0 ? tag.id.to_s : tag.name }.join(',')
    params = tag_query.blank? ? {} : { querytags: tag_query }
    url = refresh_feed_path(feed, params)

    if feed.good?
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

  def feed_update_button feed, force=false
    link_to_submit 'Update', refresh_feed_path(feed), feed_wait_msg(feed, force).merge(:button_size => 'xs')
  end

  def feed_update_trigger feed, force=false
    if feed.pending!
      last_entry = feed.feed_entries.order('published_at DESC').first
      last_entry_id = last_entry ? last_entry.id : 0
      querify_item 'Check for Updates',
                   { last_entry_id: last_entry_id },
                   feed_wait_msg(feed, force).merge(:button_size => 'xs')
    end
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
    feed_entries_status(feed) + feed_update_button(feed, true)
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


end
