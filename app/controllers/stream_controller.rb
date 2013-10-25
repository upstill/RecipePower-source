require 'reloader/sse'

class StreamController < ApplicationController
  include ActionController::Live
  
  # before_filter :setup_collection
  # before_filter :send_header
  
  def send_header
  end
  
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
    kind = params[:kind] || "ContentSeeker"
    response.headers["Content-Type"] = "text/event-stream"
    # response.stream.write "data: <div>This is a result ##{n.to_s}</div>\n\n"
    # response.stream.write "data: <div>This is another result ##{n.to_s}</div>\n\n"
    kind.sub! /Seeker$/, ''
    retrieve_seeker
    begin
      sse = Reloader::SSE.new(response.stream)
      debugger
   	  @seeker.results_paged[0..2].each do |element| 
        item = with_format("html") { view_context.seeker_stream_item element }
        sse.write :stream_item, item
   	  end
    rescue IOError
      logger.info "Stream closed"
    ensure
      # response.stream.write "event: end_of_stream\ndata: null\n\n"
      sse.close
    end
  end

end
