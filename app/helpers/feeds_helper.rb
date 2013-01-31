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
end
