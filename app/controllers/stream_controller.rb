class StreamController < ApplicationController
  include ActionController::Live
  
  # before_filter :setup_collection
  # before_filter :send_header
  
  def send_header
  end
  
  def buffer_test
    response.headers["Content-Type"] = "text/event-stream"
    response.stream.write "data: Here's an item\n\n"
    sleep(5)
    response.stream.write "data: Here's another item\n\n"
    sleep(5)
    response.stream.write "data: Here's the last item\n\n"
  rescue IOError
    logger.info "Stream closed"
  ensure
    response.stream.close
  end

  # Streams items in the current query
  def stream
    response.headers["Content-Type"] = "text/event-stream"
    # response.stream.write "data: <div>This is a result ##{n.to_s}</div>\n\n"
    # response.stream.write "data: <div>This is another result ##{n.to_s}</div>\n\n"
    setup_collection false
 	  @seeker.results_paged.each do |element| 
      item = with_format("html") { view_context.collection_element element } # "<div>Just one element</div" # 
      itemstr = JSON.dump ( { elmt: item } )
      response.stream.write "event: collection_element\ndata: #{itemstr}\n\n"
 	  end
  rescue IOError
    logger.info "Stream closed"
  ensure
    response.stream.write "event: end_of_stream\ndata: null\n\n"
    response.stream.close
  end

end