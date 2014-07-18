class IntegersController < ApplicationController
  def index
    # StreamPresenter.new.render # Sets up stream content and stream footer
    @sp = StreamPresenter.new params
    if @sp.stream_now?  # We're here to spew items into the stream

    end
    @stream_contents = with_format("html") { render_to_string partial: "stream_contents" }.html_safe
    @stream_footer = with_format("html") { render_to_string partial: "stream_footer" }.html_safe
  end
end
