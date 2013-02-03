module FeedsHelper
  def feedlist
    @feed.items.collect { |item|
      publish_date = item.published ? "Published on: "+item.published.strftime("%B %d, %Y")+"<br />" : ""
      %Q{
        <p><a href='#{item.url}'>#{item.title}
       </a><br />
       #{publish_date}
       #{item.summary}</p><hr>
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
