require 'test_helper'
require './lib/html_utils.rb'
class ContentTest < ActiveSupport::TestCase

  test "rationalize linefeeds in text" do
    str = "\nSome\n\ntext\nwith \nline\n feeds\n"
    assert_equal " Some text with line feeds ", process_dom(str)

    str = "\nSome\n\ntext\n<br>\n<br>with \nline\n breaks\n"
    assert_equal " Some text  <br>with line breaks ", process_dom(str)
  end

  test "reduce a series of br tags to one" do
    str = "some text, then some breaks\n<br>\n<br>\n<br>"
    assert_equal "some text, then some breaks   <br>", process_dom(str)
  end

  test "eliminate br tags preceding p tags" do
    str = "some text, then some breaks\n<br>\n<p>\n<br></p>"
    assert_equal "some text, then some breaks  <p> <br></p>", process_dom(str)
  end

  test "eliminate silly whitespace" do
    str = "<div class=\"entry-content\">\n<br>\t\t\n<br>\t\n<br>\n<br>\t\n<br><p><b>Coconut Milk Fudge</p></div>"
    assert_equal "<div class=\"entry-content\">     <p><b>Coconut Milk Fudge</b></p>\n</div>", process_dom(str)
  end
end