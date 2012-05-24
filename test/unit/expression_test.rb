# encoding: UTF-8
require 'test_helper'
class ExpressionTest < ActiveSupport::TestCase 
    fixtures :referents
    fixtures :tags
    
    test "Create expression" do
        ref = FoodReferent.create
        
        tagid = tags(:jal).id
        assert tags(:jal).save, "Couldn't save tag"
        jal = Tag.find tagid
        
        tagid = tags(:jal2).id
        assert tags(:jal2).save, "Couldn't save tag"
        jal2 = Tag.find tagid
        
        tagid = tags(:chilibean).id
        assert tags(:chilibean).save, "Couldn't save tag"
        chilibean = Tag.find tagid
        
        ref.express jal, locale: :es
        assert_equal "jalapeño peppers", ref.name, "Didn't adopt name when expressed"
        ref.express jal2, form: :plural
        ref.express chilibean, form: :generic, locale: :en
        
        assert_equal "chili bean", ref.name, "Didn't adopt name when expressed"
        assert_equal "jalapeño peppers", ref.expression(locale: :es).name, "Didn't find Spanish name"
        assert_equal "Chipotle -chiles", ref.expression(form: :plural).name, "Didn't find plural"
        
    end
end