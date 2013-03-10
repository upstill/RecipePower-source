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
end
