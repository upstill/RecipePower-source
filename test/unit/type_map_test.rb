# encoding: UTF-8
require 'test_helper'
require 'type_map.rb'
class TypeMapTest < ActiveSupport::TestCase 
    @@TestTbl = { 
        en: ["English", 1],
        it: ["Italian", 2], 
        na: ["North American", 3],
        fr: ["French",  4]
    }
    
    test "num" do
        tm = TypeMap.new @@TestTbl, "nil entry"
        assert_equal 2, tm.num(2), "Didn't map 2 to 2"
        assert_equal 2, tm.num(:it), "Didn't map ':it' to 2"
        assert_equal 2, tm.num("Italian"), "Didn't map 'Italian' to 2"
        assert_equal tm.num("North American"), tm.num("NorthAmerican"), "Didn't strip spaces"
    end
    
    test "nil" do 
        tm = TypeMap.new @@TestTbl, "nil entry"
        assert_equal 0, tm.num(nil), "Doesn't map nil to 0"
        assert_equal 0, tm.num(""), "Doesn't map '' to 0"
        assert_equal "nil entry", tm.name(0), "Doesn't map 0 to default name"
    end
    
    test "sym" do
        tm = TypeMap.new @@TestTbl, "nil entry"
        assert_equal :it, tm.sym(2), "Didn't map 2 to ':it'"
        assert_equal :it, tm.sym(:it), "Didn't map ':it' to ':it'"
        assert_equal :it, tm.sym("Italian"), "Didn't map 'Italian' to ':it'"
    end
    
    test "name" do
        tm = TypeMap.new @@TestTbl, "nil entry"
        debugger
        assert_equal "North American", tm.name(3), "Didn't map 3 to 'North American'"
        assert_equal "North American", tm.name(:na), "Didn't map 3 to 'North American'"
        assert_equal "North American", tm.name("North American"), "Didn't map 'North American' to 'North American'"
        assert_equal "North American", tm.name("NorthAmerican"), "Didn't map 'NorthAmerican' to 'North American'"
    end
    
    test "stripped name" do
        tm = TypeMap.new @@TestTbl, "nil entry"
        assert_equal "NorthAmerican", tm.stripped_name(3), "Didn't map 3 to 'NorthAmerican'"
    end
end
