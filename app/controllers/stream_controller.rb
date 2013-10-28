require 'reloader/sse'

class StreamController < ApplicationController
  include ActionController::Live
  
  def buffer_test
    response.headers["Content-Type"] = "text/event-stream"
    sse = Reloader::SSE.new(response.stream)
    sse.write text: "Here's an item" 
    sleep(5)
    sse.write text: "Here's another item"
    sleep(5)
    sse.write text: "Here's the last item"
  rescue IOError
    logger.info "Stream closed"
  ensure
    sse.close
  end

  # Streams items in the current query
  def stream
    response.headers["Content-Type"] = "text/event-stream"
    retrieve_seeker
    begin
      sse = Reloader::SSE.new(response.stream)
   	  @seeker.results_paged[0..2].each do |element| 
        item = with_format("html") { view_context.seeker_stream_item element }
        sse.write :stream_item, item
   	  end
    rescue IOError
      logger.info "Stream closed"
    ensure
      sse.close
    end
  end

end
