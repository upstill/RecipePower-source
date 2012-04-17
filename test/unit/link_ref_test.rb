# encoding: UTF-8
require 'test_helper'
class LinkRefTest < ActiveSupport::TestCase 
    fixtures :links
    fixtures :tags
    
    test "Link to tag successfully established" do
        jplink = "http://www.foodista.com/food/WGS253J7/jalapeno-pepper"
        jptype = :Food
        jpname = "jalapeño pepper"
        LinkRef.associate jplink, jpname, tagtype: jptype
        tag = Tag.assert_tag jpname, tagtype: jptype
    end
    
    test "Various tags and types go to same link" do
        jplink = "http://www.foodista.com/food/WGS253J7/jalapeno-pepper"
        jptype1 = :Food
        jptype2 = :Role
        jpname1 = "jalapeño pepper"
        jpname2 = "jalapeño chile"

        t1a = Tag.assert_tag jpname1, tagtype: jptype1
        puts "First Link Assert on tag #{t1a.id}"
        l1 = LinkRef.associate jplink, jpname1, tagtype: jptype1
        t1b = Tag.assert_tag jpname1, tagtype: jptype1
        assert_equal t1a, t1b, "Tags are different before and after associate"
        assert l1.tag_ids.include?(t1a.id), "Link's tags (#{l1.tag_ids.to_s}) don't include original tag (#{t1a.id})"

        t2 = Tag.assert_tag jpname1, tagtype: jptype2
        puts "Second Link Assert on tag #{t2.id}"
        l2 = LinkRef.associate jplink, jpname1, tagtype: jptype2
        assert_equal l1, l2, "Links should be the same across associations"
        assert_equal 2, l2.tag_ids.count, "Should now have two tags in list #{l2.tag_ids.to_s}"
        assert l2.tag_ids.include?(t2.id), "Link's tags (#{l2.tag_ids.to_s}) don't include existing tag #{t2.id.to_s}"
        assert l2.tag_ids.include?(t1a.id), "Link's tags (#{l2.tag_ids.to_s}) don't include first tag #{t1a.id.to_s}"
        
        LinkRef.associate jplink, jpname2, tagtype: jptype1
        LinkRef.associate jplink, jpname2, tagtype: jptype2
        t1 = Tag.assert_tag jpname1, tagtype: jptype1
        t2 = Tag.assert_tag jpname1, tagtype: jptype2
        t3 = Tag.assert_tag jpname2, tagtype: jptype1
        t4 = Tag.assert_tag jpname2, tagtype: jptype2
        assert_equal t1.link_ids.first, t2.link_ids.first, "#{jpname1} as #{jptype1.to_s} and #{jpname1} as #{jptype2.to_s} don't have same link"
        assert_equal t1.link_ids.first, t3.link_ids.first, "#{jpname1} as #{jptype1.to_s} and #{jpname2} as #{jptype1.to_s} don't have same link"
        assert_equal t1.link_ids.first, t4.link_ids.first, "#{jpname1} as #{jptype1.to_s} and #{jpname2} as #{jptype2.to_s} don't have same link"

        # The link should now be associated with all the above tags
        assert_equal 4, l1.tag_ids.count, "Should now have four tags in list #{l1.tag_ids.to_s}"
        assert l1.tag_ids.include?(t1.id), "Link's list of tags #{l1.tag_ids.to_s} doesn't include #{t1.id.to_s}"
        assert l1.tag_ids.include?(t2.id), "Link's list of tags #{l1.tag_ids.to_s} doesn't include #{t2.id.to_s}"
        assert l1.tag_ids.include?(t3.id), "Link's list of tags #{l1.tag_ids.to_s} doesn't include #{t3.id.to_s}"
        assert l1.tag_ids.include?(t4.id), "Link's list of tags #{l1.tag_ids.to_s} doesn't include #{t4.id.to_s}"
    end
    
    test "LinkRef takes keys and whole tags, not just strings" do
        jplink = "http://www.foodista.com/food/WGS253J7/jalapeno-pepper"
        jptype1 = :Food
        jptype2 = :Role
        jpname1 = "jalapeño pepper"
# jpname2 = "jalapeño chile"
        t1 = Tag.assert_tag jpname1, tagtype: jptype1
        t2 = Tag.assert_tag jpname1, tagtype: jptype2
# t3 = Tag.assert_tag jpname2, tagtype: jptype1
# t4 = Tag.assert_tag jpname2, tagtype: jptype2
        l1 = LinkRef.associate jplink, jpname1, tagtype: jptype1
        l2 = LinkRef.associate jplink, t1
        assert_equal 1, l2.tag_ids.count, "Redundant association with tag shouldn't add tag"
        l2 = LinkRef.associate jplink, t1.id
        assert_equal 1, l2.tag_ids.count, "Redundant association with tag as id shouldn't add tag"
        l2 = LinkRef.associate jplink, t2
        assert_equal 2, l2.tag_ids.count, "Association of new class tag adds it"
    end
    
    test "Link's set shouldn't change for redundant tags" do
        jplink = "http://www.foodista.com/food/WGS253J7/jalapeno-pepper"
        jptype2 = :Role
        jpname2 = "jalapeño chile"
        l1 = LinkRef.associate jplink, jpname2, tagtype: jptype2
        # Asserting an equivalent tag doesn't change link's list 
        jpname2munged1 = "jalapeno chile"
        jpname2munged2 = "Jalapeño chile"
        jpname2munged3 = "jalapeño CHILE"
        jpname2munged4 = "Jalapeno CHILE"
        LinkRef.associate jplink, jpname2munged1, tagtype: jptype2
        assert_equal 1, l1.tag_ids.count, "Should still have four tags in list #{l1.tag_ids.to_s} after asserting #{jpname2munged1}"
        LinkRef.associate jplink, jpname2munged2, tagtype: jptype2
        assert_equal 1, l1.tag_ids.count, "Should still have four tags in list #{l1.tag_ids.to_s} after asserting #{jpname2munged2}"
        LinkRef.associate jplink, jpname2munged3, tagtype: jptype2
        assert_equal 1, l1.tag_ids.count, "Should still have four tags in list #{l1.tag_ids.to_s} after asserting #{jpname2munged3}"
        LinkRef.associate jplink, jpname2munged4, tagtype: jptype2
        assert_equal 1, l1.tag_ids.count, "Should still have four tags in list #{l1.tag_ids.to_s} after asserting #{jpname2munged4}"
    end
end