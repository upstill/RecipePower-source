# encoding: UTF-8
require 'test_helper'
class TagTest < ActiveSupport::TestCase 
    fixtures :tags
    fixtures :referents
    fixtures :expressions
    
    # ------------- Data Integrity -----------------
    
    # Tag save strips excess whitespace
    test "tag stripped down" do
        puts tags(:jal).name
    end
    
    # Assert of empty string returns nil
    test "no empty tags" do
        assert_nil Tag.assert "      "
    end
    
    # Assert of string with nothing but whitespace returns nil
    test "no blank tags" do
        assert_nil Tag.assert(""), "Non-nil result from asserting blank tag."
    end
    
    # Asserting invalid tag id returns nil
    test "asserted tag ids must be valid" do
        assert_nil Tag.assert -1
    end
    
    # Asserting valid tag id returns that tag
    test "asserting valid tag ids must succeed" do
        valid_id = tags(:jal).id
        assert_equal Tag.assert(valid_id).id, valid_id
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
        assert_equal "cafe", Tag.assert("CAfé").normalized_name
        assert_equal "joes-bar-grille-and-restaurant", Tag.assert(" Joe's Bar, Grille and   - -Restaurant  ").normalized_name
        tag = Tag.find_or_initialize_by name: tags(:chilibean).name
        assert_equal tags(:chilibean).name, tag.name, "'chili bean' not found by name"
        assert_equal "chile-bean", tag.normalized_name, "'chili bean' should normalize to 'chile-bean'"
    end
    
    # String matching is immune to differences of diacriticals, capitals and punctuation
    test "String matching ignores diacriticals and capitals and punctuation" do
        assert_equal Tag.assert("cafe"), Tag.assert("CAfé")
        assert_equal Tag.assert("joes-bar-grille-and-restaurant"), Tag.assert(" Joe's Bar, Grille and   - -Restaurant  ")
        assert_equal Tag.assert(" Jills Bar, Grille and   - -Restaurant  "), Tag.assert("jills-bar-grille-and-restaurant")
        chock_full_o_punctuation = %q{chock.full,'‘of’“punctuation”'"}
        assert_equal Tag.assert("chockfullofpunctuation"), Tag.assert(chock_full_o_punctuation)
    end

    # :matchall does not match substring
    test "substring match must fail under :matchall" do 
        Tag.assert "substring"
        assert_nil Tag.strmatch("substrin", matchall: true).first
    end

    # :matchall matches whole string
    test "full string match must succeed under :matchall" do 
        t = Tag.assert "substring"
        assert_equal Tag.strmatch("substring", matchall: true).first, t
    end
        
    # ----- Security and Privacy ---------------
    # Tag made global when asserted by nil user
    test "nil user makes global tags" do
        assert Tag.assert("random tag", userid: nil).isGlobal
    end
    
    # ---------- type integrity ------------------
    
    # Tag takes on specified type
    test "tag takes on specified type" do
        assert_equal 6, Tag.assert("tag2check", 6).tagtype
        assert_equal 1, Tag.assert("genretagcheck", :Genre ).tagtype
        assert_equal 1, Tag.assert("genretagcheck2", "Genre" ).tagtype
    end
    
    # String matches for given type
    test "tag match succeeds against type" do
        t = Tag.assert("tagtypecheck", 1)
        assert_equal t, Tag.strmatch("tagtypecheck", tagtype: 1).first
    end
    
    # String matches for nonspecified
    test "tag match succeeds for unspecified type" do
        t = Tag.assert("tagtypecheck", 1)
        assert_equal t, Tag.strmatch("tagtypecheck").first
    end
    
    # String doesn't match for other types
    test "tag match fails against other types" do
        t = Tag.assert("tagtypecheck", 1)
        assert_not_equal t, Tag.strmatch("tagtypecheck", tagtype: 2).first
    end
    
    # String matches for given set of types
    test "tag matches against set of types" do
        t = Tag.assert("tagtypecheck", 1)
        assert_equal t, Tag.strmatch("tagtypecheck", tagtype: [1,2,3], matchall: true).first
    end
    
    # String matches for given set of types
    test "tag matched against empty set of types matches any" do
        t = Tag.assert("tagtypecheck", 1)
        assert_equal t, Tag.strmatch("tagtypecheck", tagtype: [], matchall: true).first
    end
    
    # String doesn't match for other sets of types
    test "tag match against nonmatching typeset fails" do
        t = Tag.assert("tagtypecheck", 1)
        assert_not_equal t, Tag.strmatch("tagtypecheck", tagtype: [4,5,6], matchall: true).first
    end
    
    test "typenum functions correctly" do
        # assert_equal 1, Tag.typenum("genre"), "Lower-case string not parsed correctly"
        # assert_equal 3, Tag.typenum("PROCESS"), "all-caps string not parsed correctly"
        assert_equal 0, Tag.typenum("free tag"), "lower-case 'free tag' not parsed correctly"
        assert_equal 0, Tag.typenum(nil), "nil doesn't return nil"
        assert_equal 4, Tag.typenum(4), "Integer type not returned"
        assert_equal [5,7,8], Tag.typenum([:Unit, 7, "Occasion"]), "Array of types not parsed correctly"
    end
    
    test "Synonyms identified correctly" do
      pie = tags(:pie)
      pies = tags(:pies)
      assert_equal [pies], TagServices.new(pie).synonyms(true)

      dessert = tags(:dessert)
      desserts = tags(:desserts)
      assert_equal [desserts], TagServices.new(dessert).synonyms(true)

      cake = tags(:cake)
      cakes = tags(:cakes)
      gateau = tags(:gateau)
      cake_syns = TagServices.new(cake).synonyms(true)
      assert cake_syns.include?(cakes), "Cake should have cakes as synonym"
      assert cake_syns.include?(gateau), "Cake should have gateau as synonym"
      assert_equal 2, cake_syns.count, "Cake should only have two synonyms"
    end

    test "Children identified correctly" do
      pie = tags(:pie)
      pies = tags(:pies)
      dessert = tags(:dessert)
      desserts = tags(:desserts)
      cake = tags(:cake)
      cakes = tags(:cakes)
      gateau = tags(:gateau)
      children = TagServices.new(dessert).children
      assert children.include?(pie), "Children of dessert should include pie."
      assert children.include?(pies), "Children of dessert should include pies."
      assert children.include?(cake), "Children of dessert should include cake."
      assert children.include?(cakes), "Children of dessert should include cakes."
      assert children.include?(gateau), "Children of dessert should include gateau."
      assert_equal 5, children.count, "Dessert should only have five children."
    end

    test "Parent identified correctly" do
      pie = tags(:pie)
      dessert = tags(:dessert)
      desserts = tags(:desserts)
      parents = TagServices.new(pie).parents
      assert parents.include?(dessert), "Parents of pie should include dessert."
      assert parents.include?(desserts), "Parents of pie should include dessert."
      assert_equal 2, parents.count, "Pie should have just two parents."
    end
    
    test "Semantic neighborhood works" do
      pie = tags(:pie)
      pies = tags(:pies)
      dessert = tags(:dessert)
      desserts = tags(:desserts)
      cake = tags(:cake)
      cakes = tags(:cakes)
      gateau = tags(:gateau)
      nb = TagServices.semantic_neighborhood(dessert.id, 0.4)
      assert_equal 1.0, nb[dessert.id], "Dessert should have weight 1 in its semantic neighborhood"
      assert_equal 1.0, nb[desserts.id], "Desserts should have weight 1 in dessert's semantic neighborhood"
      assert_equal 0.5, nb[cake.id], "Cake should have weight 0.5 in dessert's semantic neighborhood"
      nb = TagServices.semantic_neighborhood(dessert.id, 0.8)
      assert !nb.any? { |neighbor| neighbor[1] < 0.8 }, "No neighbor should have weight below imposed threshold of 0.8"
    end
end
