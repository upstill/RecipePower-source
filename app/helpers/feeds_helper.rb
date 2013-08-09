module FeedsHelper
  def feedlist
    @feed.entries.collect { |entry|
      publish_date = entry.published_at ? "Published on: "+entry.published_at.strftime("%B %d, %Y")+"<br />" : ""
      %Q{
        <p><a href='#{entry.url}'>#{entry.name}
       </a><br />
       #{publish_date}
       #{entry.summary}</p><hr>
      }
    }.join.html_safe
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
  
  def feeds_table
    table_out @feeds, [ "ID", "Title/Description/URL", "Tag(s)", "Type", "Host Site", permitted_to?(:approve, :feeds) && "Approved", "Actions" ] do |feed|
      @feed = feed
      render "feeds/feed"
    end
  end
  
  def feed_approval

    if @feed.approved.nil?
      yes_btn = link_to 'Y', approve_feed_path(@feed, approve: "Y"), class: "btn btn-mini", remote: true, method: "POST"
      no_btn = link_to 'N', approve_feed_path(@feed, approve: "N"), class: "btn btn-mini", remote: true, method: "POST"
  		(yes_btn+no_btn).html_safe
  	else
  	  @feed.approved ? "Y" : "N"
	  end
	end
	
end
