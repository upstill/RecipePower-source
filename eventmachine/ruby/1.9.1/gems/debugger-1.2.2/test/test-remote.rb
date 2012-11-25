require 'test/unit'
require 'socket'
require 'ruby-debug'

# Test Debugger.start_remote, Debugger.cmd_port and Debugger.ctrl_port
class TestRemote < Test::Unit::TestCase
  def test_remote
    Debugger.start_remote('127.0.0.1', [0, 0])
    assert_block { Debugger.ctrl_port > 0 }
    assert_block { Debugger.cmd_port > 0 }
    assert_nothing_raised { TCPSocket.new('127.0.0.1', Debugger.ctrl_port).close }
    assert_nothing_raised { TCPSocket.new('127.0.0.1', Debugger.cmd_port).close }
  end
end
