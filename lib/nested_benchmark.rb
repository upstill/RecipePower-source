class NestedBenchmark
  @indent = 0
  def self.measure msg
    puts 'BBBB >>>>>>>>>>>>>> Begin Benchmarking -----------------' if @indent == 0
    @indent += 4
    result = nil
    vals = Benchmark.measure {
      result = yield
    }
    @indent -= 4
    puts self.at_left(msg, @indent) + vals.to_s
    puts 'BBBB <<<<<<<<<<<<<< End Benchmarking -----------------' if @indent == 0
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