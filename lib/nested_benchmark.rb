class NestedBenchmark
  @indent = 0

  def self.log msg
    if Rails.env.development? # Write to console when in development
      puts msg
    else
      Rails.logger.debug 'BENCHMARK: '+msg
    end
  end

  def self.measure msg
    log('>>>>>>>>>>>>>> Begin Benchmarking ---- user system user+system (total elapsed)') if @indent == 0
    @indent += 4
    result = nil
    vals = Benchmark.measure {
      result = yield
    }
    @indent -= 4
    log self.at_left(msg, @indent) + vals.to_s
    log('<<<<<<<<<<<<<< End Benchmarking -----------------') if @indent == 0
    result
  end

  # Make the string for embedding before the numbers
  def self.at_left msg, indent
    pad_before = ' ' * @indent
    afterlength = (50 + @indent) - (msg.length + @indent)
    pad_after = ' ' * (afterlength > 0 ? afterlength : 1)
    pad_before + msg + pad_after
  end
end