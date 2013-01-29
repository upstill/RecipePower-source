module FeedsHelper
  def feedlist
    @feed.items.collect { |item|
      %Q{
        <p><a href='#{item.link}'>#{item.title}
       </a><br />
          Published on: #{item.date.strftime("%B %d, %Y")}
       <br />
       #{item.description}</p><hr>
      }
    }.join.html_safe
  end
end
