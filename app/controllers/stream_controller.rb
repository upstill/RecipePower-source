require 'reloader/sse'

class StreamController < ApplicationController
=begin
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
      results = nil
      time = Benchmark.measure { results = @seeker.results_paged }
      File.open("db_timings", 'a') { |file| file.write("Seeker Page (#{Time.new} unindexed): "+time.to_s+"\n") }
      if results.empty?
        sse.write :stream_item,
                  view_context.element_item('.collection_list',
                                            view_context.flash_one(:notice, @seeker.explain_empty))
      else
        results.each do |element|
          item = with_format("html") { view_context.seeker_stream_item element }
          sse.write :stream_item, item
        end
      end
    rescue IOError
      logger.info "Stream closed"
    ensure
      sse.close done: true # more_to_come: (@seeker.npages > @seeker.cur_page)
    end
  end
=end

end
