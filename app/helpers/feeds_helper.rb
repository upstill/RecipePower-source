module FeedsHelper

  def feeds_table
    stream_table [ "ID", "Title/Description/URL", "Tag(s)", "Type", "Host Site", ("Approved" if permitted_to?(:approve, :feeds)) , "Actions" ].compact
  end

  def feedlist
    @feed.entries.collect { |entry| render partial: "feed_entries/show_feed_entry", item: entry }.join.html_safe
  end
  
=begin
:name         => entry.title,
:summary      => entry.summary,
:url          => entry.url,
:published_at => entry.published,
:guid         => entry.id,
:feed         => feed
=end
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
  
  def feed_approval feed

    if feed.approved.nil?
      yes_btn = link_to 'Y', approve_feed_path(feed, approve: "Y"), class: "btn btn-default btn-xs", remote: true, method: "POST"
      no_btn = link_to 'N', approve_feed_path(feed, approve: "N"), class: "btn btn-default btn-xs", remote: true, method: "POST"
  		(yes_btn+no_btn).html_safe
  	else
  	  feed.approved ? "Y" : "N"
	  end
	end
	
end
