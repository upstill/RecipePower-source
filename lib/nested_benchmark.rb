class NestedBenchmark
  @indent = 0
  @@DOLOG=false # No benchmarking unless set

  def self.do_log
    @@DOLOG
  end

  def self.do_log=on
    @@DOLOG = on
  end

  def self.log msg
    return unless @@DOLOG
    if Rails.env.development? # Write to console when in development
      puts msg
    else
      Rails.logger.debug 'BENCHMARK: '+msg
    end
  end

  def self.measure msg
    return yield unless @@DOLOG
    open = '('
    close = ')'
    bracket_len = 6
    log "\n" + self.at_right('',' Begin Benchmarking ---- user system user+system (total elapsed)', '<') if @indent == 0
    @indent += 4
    result = err = nil
    vals = Benchmark.measure {
      begin
        result = yield
      rescue Exception => e
        err = e
      end
    }
    @indent -= 4
    # log self.at_left(msg, @indent) + vals.to_s
    log self.at_right(msg, vals.to_s)
    log self.at_right('', ' End Benchmarking ------ user system user+system (total elapsed)', '>')+"\n" if @indent == 0
    # log("<<<<<<<<<<<<<< End Benchmarking -----------------\n") if @indent == 0
    raise err if err
    result
  end

  # Make the string for embedding before the numbers
  def self.at_left msg, indent
    pad_before = ' ' * @indent
    afterlength = (50 + @indent) - (msg.length + @indent)
    pad_after = ' ' * (afterlength > 0 ? afterlength : 1)
    pad_before + msg + pad_after
  end

  def self.at_right msg, vals, closer='|'
    vals = vals.strip
    slack = 120-(msg.length+vals.length+2*@indent)
    if slack < 0
      msg = msg.truncate(msg.length + slack)
      middle_padding = ''
    else
      middle_padding = ' ' * slack
    end
    result = (' ' * @indent) + msg + middle_padding + vals + (' ' * @indent) + closer*2
    # result.length.to_s + ':' + result
  end
end