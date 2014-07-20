require 'reloader/sse'

class IntegersController < ApplicationController
  include ActionController::Live

  def index
    # StreamPresenter.new.render # Sets up stream content and stream footer
    @sp = StreamPresenter.new params
    if @sp.stream?  # We're here to spew items into the stream
      response.headers["Content-Type"] = "text/event-stream"
      # retrieve_seeker
      begin
        sse = Reloader::SSE.new(response.stream)
        while item = @sp.next_item do
          sse.write :stream_item, with_format("html") { view_context.emit_stream_item item }
        end
      rescue IOError
        logger.info "Stream closed"
      ensure
        sse.close more_to_come: !@sp.next_path.blank? # (@seeker.npages > @seeker.cur_page)
      end
    end
  end
end
