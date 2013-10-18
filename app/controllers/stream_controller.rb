class StreamController < ApplicationController
  include ActionController::Live
  
  # before_filter :setup_collection
  # before_filter :send_header
  
  def send_header
  end

  # Streams items in the current query
  def stream
    response.headers["Content-Type"] = "text/event-stream"
    # response.stream.write "data: <div>This is a result ##{n.to_s}</div>\n\n"
    # response.stream.write "data: <div>This is another result ##{n.to_s}</div>\n\n"
    setup_collection false
    n = 1
    debugger
    response.stream.write "data: Here's an item\n\n"
    response.stream.write "data: Here's another item\n\n"
    response.stream.write "data: Here's a third item\n\n"
=begin
 	  @seeker.results_paged[0..5].each do |element| 
 	    # itemstr = with_format("html") { render_to_string partial: "collection/element", locals: { element: element }}
 	    # item = with_format("html") { view_context.collection_element element }
      itemstr = "<div>nothing special</div>" # JSON.dump ({ elmt: item }) # element.id })
      n = n+1
      debugger
      response.stream.write "event: collection_element\ndata: #{itemstr}\n\n\n"
 	  end
=end
  rescue IOError
    debugger
    logger.info "Stream closed"
  ensure
    response.stream.write "event: end_of_stream\ndata: null\n\n"
    response.stream.close
  end

end