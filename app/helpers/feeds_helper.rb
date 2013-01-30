module FeedsHelper
  def feedlist
    @feed.items.collect { |item|
      %Q{
        <p><a href='#{item.url}'>#{item.title}
       </a><br />
          Published on: #{item.published.strftime("%B %d, %Y")}
       <br />
       #{item.summary}</p><hr>
      }
    }.join.html_safe
  end
end
