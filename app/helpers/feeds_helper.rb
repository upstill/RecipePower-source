module FeedsHelper

  def feed_status_report feed
    tag_query = @querytags.collect { |tag| tag.id > 0 ? tag.id.to_s : tag.name }.join(',')
    params = tag_query.blank? ? {} : { querytags: tag_query }
    url = refresh_feed_path(feed, params)

    if feed.status == "ready"
      label = "Check for Updates"
    else
      status = "Update #{feed.status}. "
      label = "Try Again"
    end
    link = link_to_submit label, url, feed_wait_msg(feed, true).merge(button_size: "sm")
    content_tag :span,
                "Last updated #{time_ago_in_words feed.updated_at} ago. #{status}#{link}".html_safe,
                class: "feed-status-report"
  end

  def feed_wait_msg feed, force=false
    wait_msg = "Hang on, we're contacting #{feed.site.name} for updates. This could take a minute." if force || feed.due_for_update
    wait_msg ? { "wait-msg" => wait_msg } : {}
  end

  def feed_update_button feed
    link_to_submit "Update", refresh_feed_path(feed), feed_wait_msg(feed).merge(:button_size => "xs")
  end

  # Summarize the number of entries/latest entry for a feed
  def feed_status_summary feed
    entry_report =
    case nmatches = feed.feed_entries.size
      when 0
        "No&nbsp;entries"
      when 1
        "One&nbsp;entry"
      else
        "#{nmatches}&nbsp;entries"
    end
    time_report = (feed.updated_at.today?) ? "Today" : "#{time_ago_in_words feed.updated_at} ago"
    update_button = feed_update_button feed
    "#{entry_report}/<br>#{time_report} #{update_button}".html_safe
  end

  def feed_status_report_replacement feed
    [ "span.feed-status-report", feed_status_report(feed) ]
  end

  def feedlist
    @feed.entries.collect { |entry| render partial: "feed_entries/show_feed_entry", item: entry }.join.html_safe
  end
  
  # Helper for showing @feed_entry to @user_id
  def show_feed_entry
    %Q{<p>
      <a href='#{@feed_entry.url}'>#{@feed_entry.name}</a><br />
     #{@feed_entry.published_at}
     #{@feed_entry.summary}
    </p><hr>}.html_safe
  end
  
  def list_feeds preface, feeds
    count = feeds.count
    msg = [preface, (count > 1 ? count.to_s : 'a'), 'feed'.pluralize(count)].join(' ')+
          ":<br><ul><li>"+
          feeds.map(&:title).join('</li><li>')+
          "</li></ul>"
    msg.html_safe
  end

  def feed_subscribe_button item, options={}
    if item.collected? current_user_or_guest_id
      label, path = "Unsubscribe", collect_feed_path(item, oust: true)
    else
      label, path = "Subscribe", collect_feed_path(item)
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
              "Approved "
            when false
              "Blocked "
            else
              ""
          end
          str << link_to_submit('Approve', approve_feed_path(feed, approve: "Y"), button_size: "xs", method: "POST") unless feed.approved == true
          str << link_to_submit('Block', approve_feed_path(feed, approve: "N"), button_size: "xs", method: "POST") unless feed.approved == false
    content_tag :span, str.html_safe, :id => dom_id(feed)
  end

  def feed_approval_replacement feed
    [ "span##{dom_id feed}", feed_approval(feed) ]
  end

  def feeds_table
    headers = [ "Title/Description/URL", "Tag(s)", "Type", "Host Site", "# Entries/<br>Last Updated".html_safe, ("Approved" if response_service.admin_view?), "Actions" ].compact
    render "shared/stream_results_table", headers: headers
  end

end
