# encoding: UTF-8
require 'test_helper'
class RcpqueryTest < ActiveSupport::TestCase 
    fixtures :tags
    fixtures :rcpqueries
    
    test "specialtags starts out empty but not nil" do
        rq = Rcpquery.new( )
        assert !rq.specialtags.nil?, "Special tags should not initialize nil"
        assert rq.specialtags.empty?, "nospecial should have empty specialtags"
    end
    
    test "Setting tag_tokens saves tagstxt" do
        t1 = tags(:jal).id
        t2 = tags(:jal2).id
        rq = Rcpquery.new
        teststr = "#{t1},#{t2}"
        rq.tag_tokens = teststr
        assert_equal teststr, rq.tagstxt, "'#{teststr}' after assignment: '#{rq.tagstxt}'"
        rq = Rcpquery.new tag_tokens: teststr
        assert_equal teststr, rq.tagstxt, "'#{teststr}' after initializing: '#{rq.tagstxt}'"
    end
    
    test "Empty query string extracts into empty tagsets" do
        rq = Rcpquery.new
        rq.tag_tokens = ""
        tagset = rq.tags
        assert_equal Array, tagset.class, "Tagset is not an array"
        assert_equal 0, tagset.count, "Tagset has elements"
    end
    
    test "String of existing tags extracts into array of tags" do
        t1 = tags(:jal).id
        t2 = tags(:jal2).id
        tt = "#{t1},#{t2}"
        rq = Rcpquery.new
        rq.tag_tokens = tt
        tagset = rq.tags
        assert_equal Array, tagset.class, "Tagset is not an array"
        assert_equal 2, tagset.count, "Tagset has elements"
        assert_equal Tag, tagset.first.class, "Tagset are not tags"
    end
    
    test "String of one special tag extracts into one special tag" do
        tt1 = "special 1"
        rq = Rcpquery.new
        rq.tag_tokens = "'#{tt1}'"
        tagset = rq.tags
        assert_equal Array, tagset.class, "Tagset is not an array"
        assert_equal 1, tagset.count, "Tagset doesn't have exactly one element"
        tag1 = tagset.first
        assert_equal Tag, tag1.class, "Tagset doesn't have tags"
        assert_equal tt1, tag1.name, "Parsed tag wrong"
    end
    
    test "String of two special tags extracts into two special tags" do
        tt1 = "special 1"
        tt2 = "special 2"
        rq = Rcpquery.new
        rq.tag_tokens = "'#{tt1}', '#{tt2}'"
        tagset = rq.tags
        assert_equal Array, tagset.class, "Tagset is not an array"
        assert_equal 2, tagset.count, "Tagset doesn't have exactly one element"
        tag1 = tagset.first
        assert_equal Tag, tag1.class, "Tagset doesn't have tags"
        assert_equal tt1, tag1.name, "Parsed tag wrong"
        tag2 = tagset.last
        assert_equal Tag, tag2.class, "Tagset doesn't have tags"
        assert_equal tt2, tag2.name, "Parsed tag wrong"
        assert_not_equal tag1.id, tag2.id, "The two tags have the same key"
        
        # Check that the special tags correspond exactly to the tags
        st1 = rq.specialtags[tag1.id.to_s]
        assert_not_nil st1, "...from tag '#{tag1.name}'"
        assert_equal tag1.name, st1, "Tag and specialtag don't match"
        st2 = rq.specialtags[tag1.id.to_s]
        assert_not_nil st2, "...from tag '#{tag1.name}'"
        assert_equal tag1.name, st2, "Tag and specialtag don't match"
    end

    test "Special tag survives across queries" do
        tt1 = "special 1"
        tt2 = "special 2"
        rq = Rcpquery.new
        rq.tag_tokens = "'#{tt1}', '#{tt2}'"
        tagset = rq.tags
        assert_equal Array, tagset.class, "Tagset is not an array"
        assert_equal 2, tagset.count, "Tagset doesn't have exactly one element"
        tag1 = tagset.first
        assert_equal Tag, tag1.class, "Tagset doesn't have tags"
        assert_equal tt1, tag1.name, "Parsed tag wrong"
        tag2 = tagset.last
        assert_equal Tag, tag2.class, "Tagset doesn't have tags"
        assert_equal tt2, tag2.name, "Parsed tag wrong"
        assert_not_equal tag1.id, tag2.id, "The two tags have the same key"
        
        # Check that the special tags correspond exactly to the tags
        st1 = rq.specialtags[tag1.id.to_s]
        assert_not_nil st1, "...from tag '#{tag1.name}'"
        assert_equal tag1.name, st1, "Tag and specialtag don't match"
        st2 = rq.specialtags[tag1.id.to_s]
        assert_not_nil st2, "...from tag '#{tag1.name}'"
        assert_equal tag1.name, st2, "Tag and specialtag don't match"
        
        # Now we query against one of the special tags
        rq.tag_tokens = "#{tag2.id.to_s}"
        tagset = rq.tags
        assert_equal 1, tagset.count, "Tagset doesn't have exactly one element: #{tagset.to_s}"
        tag2 = tagset.first
        assert_equal Tag, tag2.class, "Tagset doesn't have tags after "
        assert_equal tt2, tag2.name, "Got special tag wrong"
        assert_equal tag2.id.to_s, rq.specialtags.keys.first, "Tag and specialtag don't have the same key"
    end
    
    test "Random query strings work and special tags survive" do
        tt1 = "special 1"
        tt2 = "special 2"
        jalid = tags(:jal).id.to_s
        jal2id = tags(:jal2).id.to_s
        rq = Rcpquery.new
        rq.tag_tokens = ""
        assert_equal 0, rq.tags.count, "Empty query string doesn't produce empty tags"
        
        rq.tag_tokens = "'#{tt1}, #{jalid}, #{jal2id}"
        assert_equal 3, rq.tags.count, "Three initial tags, one special"
        assert_equal 1, rq.specialtags.count, "One special tag in query, but got #{rq.specialtags.to_s}"
        ttl1id = rq.specialtags.keys.first
        
        rq.tag_tokens = "'#{tt2}',#{ttl1id}, #{jalid}"
        assert_equal rq.specialtags[ttl1id], tt1, "Special tag not getting saved across queries"
        
    end

end