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
    link = link_to_submit label, url, button_size: ""
    content_tag :span,
                "Last updated #{time_ago_in_words feed.updated_at} ago. #{status}#{link}".html_safe,
                class: "feed-status-report"
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
    update_button = link_to_submit "Update", refresh_feed_path(feed), :button_size => "xs", "wait-msg" => "Hang on, this could take a few seconds"
    "#{entry_report}/<br>#{time_ago_in_words feed.updated_at} ago #{update_button}".html_safe
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
    if item.collected_by? current_user_or_guest_id
      link_to_submit 'Unsubscribe', remove_feed_path(item), { method: :post, button_size: "sm" }.merge(options)
    else
      link_to_submit 'Subscribe', collect_feed_path(item), { button_size: "sm"}.merge(options)
    end
  end

  def feed_buttons item, options={}
    # ct_button = current_user.collected? item) ?
    buttons = collectible_buttons item, :tag_only, { button_size: "sm"}.merge(options) do
      feed_subscribe_button item, options
    end
    content_tag :span,
                buttons,
                class: "feed-button-span",
                id: dom_id(item)
  end

  def feed_buttons_replacement item, options={}
    [ "span.feed-button-span##{dom_id item}", feed_buttons(item, options) ]
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

  def feed_table_row feed
    with_format("html") { render "feeds/index_table_row", item: feed }
  end

  def feed_table_row_replacement feed
    [ "tr##{dom_id feed}", feed_table_row(feed) ]
  end

  def feed_table_row_nuker feed
    [ "tr##{dom_id feed}" ]
  end
end
