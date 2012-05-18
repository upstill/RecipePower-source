# encoding: UTF-8
require 'test_helper'
class TagTest < ActiveSupport::TestCase 
    fixtures :tags
    
    # ------------- Data Integrity -----------------
    
    # Tag save strips excess whitespace
    test "tag stripped down" do
        puts tags(:jal).name
    end
    
    # Assert of empty string returns nil
    test "no empty tags" do
        assert_nil Tag.assert_tag "      "
    end
    
    # Assert of string with nothing but whitespace returns nil
    test "no blank tags" do
        assert_nil Tag.assert_tag(""), "Non-nil result from asserting blank tag."
    end
    
    # Asserting invalid tag id returns nil
    test "asserted tag ids must be valid" do
        assert_nil Tag.assert_tag -1
    end
    
    # Asserting valid tag id returns that tag
    test "asserting valid tag ids must succeed" do
        valid_id = tags(:jal).id
        assert_equal Tag.assert_tag(valid_id).id, valid_id
    end
    
    test "accessing tag types by any means" do
        assert_equal :Genre, Tag.typesym("Genre"), "Name didn't turn into symbol"
        assert_equal :Genre, Tag.typesym(1), "Number didn't turn into symbol"
        assert_equal :Genre, Tag.typesym(:Genre), "Symbol didn't turn into symbol"
        tag = Tag.new :tagtype => 1
        assert_equal :Genre, tag.typesym(), "Symbol didn't read correctly"
        assert_equal 1, tag.typenum(), "Number didn't read correctly"
        assert_equal "Genre", tag.typename(), "Name didn't read correctly"
    end
    
    # ------------- Matching strings --------------------
    # Normalized_name correctly removes diacriticals, capitalization, punctuation
    test "normalized name must elide gratuity" do
        assert_equal "cafe", Tag.assert_tag("CAfé").normalized_name
        assert_equal "joes-bar-grille-and-restaurant", Tag.assert_tag(" Joe's Bar, Grille and   - -Restaurant  ").normalized_name
        tag = Tag.find_by_name tags(:chilibean).name
        assert_equal tags(:chilibean).name, tag.name, "'chili bean' not found by name"
        assert_nil tag.normalized_name, "Normalized_name should be nil for unsaved record"
        tag.save
        assert_equal "chile-bean", tag.normalized_name, "'chili bean' should normalize to 'chile-bean'"
    end
    
    # String matching is immune to differences of diacriticals, capitals and punctuation
    test "String matching ignores diacriticals and capitals and punctuation" do
        assert_equal Tag.assert_tag("cafe"), Tag.assert_tag("CAfé")
        assert_equal Tag.assert_tag("joes-bar-grille-and-restaurant"), Tag.assert_tag(" Joe's Bar, Grille and   - -Restaurant  ")
        assert_equal Tag.assert_tag(" Jills Bar, Grille and   - -Restaurant  "), Tag.assert_tag("jills-bar-grille-and-restaurant")
        chock_full_o_punctuation = %q{chock.full,'‘of’“punctuation”'"}
        assert_equal Tag.assert_tag("chockfullofpunctuation"), Tag.assert_tag(chock_full_o_punctuation)
    end

    # :matchall does not match substring
    test "substring match must fail under :matchall" do 
        Tag.assert_tag "substring"
        assert_nil Tag.strmatch("substrin", matchall: true).first
    end

    # :matchall matches whole string
    test "full string match must succeed under :matchall" do 
        t = Tag.assert_tag "substring"
        assert_equal Tag.strmatch("substring", matchall: true).first, t
    end
        
    # ----- Security and Privacy ---------------
    # Tag made global when asserted by nil user
    test "nil user makes global tags" do
        assert Tag.assert_tag("random tag", userid: nil).isGlobal
    end
    
    # ---------- type integrity ------------------
    
    # Tag takes on specified type
    test "tag takes on specified type" do
        assert_equal 6, Tag.assert_tag("tag2check", tagtype: 6).tagtype
        assert_equal 1, Tag.assert_tag("genretagcheck", tagtype: :Genre ).tagtype
        assert_equal 1, Tag.assert_tag("genretagcheck2", tagtype: "Genre" ).tagtype
    end
    
    # String matches for given type
    test "tag match succeeds against type" do
        t = Tag.assert_tag("tagtypecheck", tagtype: 1)
        assert_equal t, Tag.strmatch("tagtypecheck", tagtype: 1).first
    end
    
    # String matches for nonspecified
    test "tag match succeeds for unspecified type" do
        t = Tag.assert_tag("tagtypecheck", tagtype: 1)
        assert_equal t, Tag.strmatch("tagtypecheck").first
    end
    
    # String doesn't match for other types
    test "tag match fails against other types" do
        t = Tag.assert_tag("tagtypecheck", tagtype: 1)
        assert_not_equal t, Tag.strmatch("tagtypecheck", tagtype: 2).first
    end
    
    # String matches for given set of types
    test "tag matches against set of types" do
        t = Tag.assert_tag("tagtypecheck", tagtype: 1)
        assert_equal t, Tag.strmatch("tagtypecheck", tagtype: [1,2,3], matchall: true).first
    end
    
    # String matches for given set of types
    test "tag matched against empty set of types matches any" do
        t = Tag.assert_tag("tagtypecheck", tagtype: 1)
        assert_equal t, Tag.strmatch("tagtypecheck", tagtype: [], matchall: true).first
    end
    
    # String doesn't match for other sets of types
    test "tag match against nonmatching typeset fails" do
        t = Tag.assert_tag("tagtypecheck", tagtype: 1)
        assert_not_equal t, Tag.strmatch("tagtypecheck", tagtype: [4,5,6], matchall: true).first
    end
    
    test "typenum functions correctly" do
        # assert_equal 1, Tag.typenum("genre"), "Lower-case string not parsed correctly"
        # assert_equal 3, Tag.typenum("PROCESS"), "all-caps string not parsed correctly"
        assert_nil Tag.typenum("free tag"), "lower-case 'free tag' not parsed correctly"
        assert_equal 0, Tag.typenum(nil), "nil doesn't return nil"
        assert_equal 4, Tag.typenum(4), "Integer type not returned"
        assert_equal [5,7,8], Tag.typenum([:Unit, 7, "Occasion"]), "Array of types not parsed correctly"
    end
end