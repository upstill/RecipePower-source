class NestedBenchmark
  @indent = 0
  def self.measure msg
    logger.debug 'BBBB >>>>>>>>>>>>>> Begin Benchmarking ---- user system user+system (total elapsed)' if @indent == 0
    @indent += 4
    result = nil
    vals = Benchmark.measure {
      result = yield
    }
    @indent -= 4
    logger.debug self.at_left(msg, @indent) + vals.to_s
    logger.debug 'BBBB <<<<<<<<<<<<<< End Benchmarking -----------------' if @indent == 0
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