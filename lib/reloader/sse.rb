require 'json'

module Reloader
  class SSE
    def initialize io
      @io = io
    end

    def write event_type_or_option, options = {}
      if event_type_or_option.class == String || event_type_or_option.class == Symbol
        event_type = event_type_or_option
      else
        options.merge! event_type_or_option
        event_type = options.delete :event
      end
      event_type ||= :data
      @io.write "event: #{event_type}\n"
      jstr = JSON.dump options
      @io.write "data: #{jstr}\n\n"
    end

    def close
      write :end_of_stream
      @io.close
    end
  end
end
