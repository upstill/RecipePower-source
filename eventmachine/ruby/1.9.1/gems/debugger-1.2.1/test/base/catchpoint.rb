#!/usr/bin/env ruby
require 'test/unit'
require 'ruby_debug'

# Test catchpoint in C ruby_debug extension.

class TestRubyDebugCatchpoint < Test::Unit::TestCase

  # test current_context
  def test_catchpoints
    assert_raise(RuntimeError) {Debugger.catchpoints}
    Debugger.start_
    assert_equal({}, Debugger.catchpoints)
    Debugger.add_catchpoint('ZeroDivisionError')
    assert_equal({'ZeroDivisionError' => 0}, Debugger.catchpoints)
    Debugger.add_catchpoint('RuntimeError')
    assert_equal(['RuntimeError', 'ZeroDivisionError'],
                 Debugger.catchpoints.keys.sort)
    Debugger.stop
  end

end
