require 'test_helper'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'
require 'parse_tester'

# These are tests for the default configuration of the Parser grammar
class ParsingServicesTest < ActiveSupport::TestCase
  include PTInterface

  test 'mapping in grammar mods' do
    html = "irrelevant text"

    # Test ingredient-list declaration with classes specified
    grammar_mods = { :gm_inglist => { flavor: :unordered_list, list_class: 'wprm-recipe-ingredients', line_class: 'wprm-recipe-ingredient'} }
    parser = Parser.new html, Lexaur.from_tags, grammar_mods
    assert_equal 'ul.wprm-recipe-ingredients', parser.grammar[:rp_inglist][:match].first[:in_css_match]
    assert_equal 'li.wprm-recipe-ingredient', parser.grammar[:rp_ingline][:in_css_match]
  end
end