require 'test_helper'

class ScraperTest < ActiveSupport::TestCase

  def setup
    Answer.delete_all
    Authentication.delete_all
    Expression.delete_all
    Finder.delete_all
    List.delete_all
    Rcpref.delete_all
    Recipe.delete_all
    Reference.delete_all
    Referent.delete_all
    Referment.delete_all
    ReferentRelation.delete_all
    ResultsCache.delete_all
    Scraper.delete_all
    Site.delete_all
    Tag.delete_all
    TagOwner.delete_all
    Tagging.delete_all
    TagsCache.delete_all
    Tagset.delete_all
    User.delete_all
    UserRelation.delete_all
    Vote.delete_all
    User.super_id = (User.find(User.super_id) rescue User.create(email: 'mesuper@bogus.com')).id
  end

  def show_tags tagtype=nil
    rel = tagtype ? Tag.where(tagtype: Tag.typenum(tagtype)) : Tag.all
    Rails.logger.info "#{Tag.typename(tagtype)} Tags gleaned: " + rel.pluck(:name).join(', ')
    rel
  end

  def test_url_for_handler url, handler, should_exist=true
    Rails.logger.info "Testing '#{url}' for handler '#{handler}'"
    scraper = Scraper.assert url
    assert_equal handler.to_s, scraper.handler.to_s, "...derived handler is #{scraper.handler}"
    assert scraper.becomes(Www_bbc_co_uk_Scraper).respond_to?(handler.to_sym), '...but there\'s no such method'
    begin
      scraper.ping
      scraper.ping # See if the page exists
    rescue
      assert false if should_exist
    end
    sleep 5
  end

  test 'bbc_handlers' do
    test_url_for_handler 'http://www.bbc.co.uk/food', :bbc_food_page
    
    test_url_for_handler 'http://www.bbc.co.uk/food/chefs/by/letters/d,e,f', :bbc_chefs_atoz_page
    
    %w{ chefs recipes seasons techniques occasions cuisines ingredients }.each {  |type|
      test_url_for_handler ('http://www.bbc.co.uk/food/' + type), "bbc_#{type}_page"
    }
    
    %w{ occasions techniques seasons cuisines programmes collections diets chefs recipes ingredients }.each { |type|
      test_url_for_handler ('http://www.bbc.co.uk/food/' + type + "/mystery_entity-known"), "bbc_#{type.singularize}_home_page", false
    }
    
    %w{ dishes occasions chefs programmes courses diets cuisines ingredients }.each {  |type|
      test_url_for_handler ('http://www.bbc.co.uk/food/recipes/search?' + type + "[0]=mystery_entity-known"), "bbc_#{type.singularize}_recipes_page", false
      test_url_for_handler ('http://www.bbc.co.uk/food/recipes/search?intervening noise**_-' + type + "[0]=mystery_entity-known"), "bbc_#{type.singularize}_recipes_page", false
    }
    
    test_url_for_handler 'http://www.bbc.co.uk/food/ingredients/by/letter/c', :bbc_ingredients_by_letter
    
    test_url_for_handler 'http://www.bbc.co.uk/food/broccoli', :bbc_ingredient_home_page
    
  end

  # Home page for BBC Food
  test 'bbc_food_page' do
    url = 'http://www.bbc.co.uk/food'
    scraper = Scraper.assert url
    assert_equal :bbc_food_page, scraper.handler
    scraper.perform_naked

    assert_equal 9, show_tags(:Diet).count
    assert_equal 9, Scraper.where(what: 'bbc_diet_home_page').count
  end

  # Home page for a diet
  test 'bbc_diet_home_page' do
    url = 'http://www.bbc.co.uk/food/diets/dairy_free'
    scraper = Scraper.assert url, true
    assert_equal :bbc_diet_home_page, scraper.handler
    scraper.perform_naked

    diet_tags = show_tags :Diet
    diet_tag = diet_tags.first
    assert_equal 1, diet_tags.count
    assert_equal 'dairy-free', diet_tag.name
    assert_equal 1, Scraper.where(what: 'bbc_diet_recipes_page').count

    assert_equal 3, diet_tag.referents.first.references.count # The home page and two external pages

    assert_equal 8, Tag.where(tagtype: Tag.typenum(:Course)).count
    assert_equal 45, diet_tag.recipes.count
  end

  test 'bbc_recipe_search_page' do
    def search_class_for_type type
      case type
        when :Source
          'programme'
        when :Author
          'chef'
        when :Genre
          'cuisine'
        else
          type.to_s.downcase
      end
    end
    searchable_types = {
        :Dish => 'cake',
        :Occasion => 'christmas',
        :Author => 'antonio_carluccio',   # 'chefs'
        :Source => 'b04gtx26',            # 'programmes'
        :Course => 'side_dishes',
        :Diet => 'dairy_free',
        :Genre => 'british',               # 'cuisines'
        # :Ingredient => 'candied peel' No need to scrape ingredient recipes page, since ingredients appear in recipes
    }
    searchable_types.each { |key, value|
      search_class = search_class_for_type key
      url = "http://www.bbc.co.uk/food/recipes/search?#{search_class.pluralize}[]=#{value}&page=2"
      scraper = Scraper.assert url, true
      assert_equal scraper.handler, "bbc_#{search_class}_recipes_page".to_sym
      scraper.save
      scraper.perform_naked

      check_recipes_result key, true
      url = "http://www.bbc.co.uk/food/recipes/search?#{search_class.pluralize}[]=#{value}"
      scraper = Scraper.assert url, true
      assert_equal scraper.handler, "bbc_#{search_class}_recipes_page".to_sym
      scraper.save
      scraper.perform_naked

      check_recipes_result key, false
      setup
    }
  end

  def check_recipes_result rp_type, notags=false
    assert (Recipe.count > 10), "Only #{Recipe.count} recipes found on #{rp_type} page"
    assert Scraper.where('url LIKE ?', '%page=%').exists?, "No link to second page of results"

    ([ :Dish, :Course, :Genre ] - [ rp_type ]).each { |typesym|
      if notags
        assert ((show_tags typesym).count < 2), "Found #{typesym} tag(s) when none expected" # No tag gleaning on pages after the first
      else
        assert ((show_tags typesym).count > 1), "Found no #{typesym} tags on first page" # No tag gleaning on pages after the first
      end
    }
  end

  test 'bbc_programme_recipes_page' do
    url = 'http://www.bbc.co.uk/food/recipes/search?programmes[]=b04gtx26'
    scraper = Scraper.assert url, true
    assert_equal scraper.handler, :bbc_programme_recipes_page
    scraper.save
    scraper.perform_naked
    check_recipes_result :Source
  end

  test 'bbc_chef_recipes_page' do
    url = 'http://www.bbc.co.uk/food/recipes/search?chefs[]=antonio_carluccio'
    scraper = Scraper.assert url, true
    assert_equal scraper.handler, :bbc_chef_recipes_page
    scraper.save
    scraper.perform_naked

    # Should have defined the author tag
    ats = Tag.where tagtype: Tag.typenum(:Author)
    at = ats.first
    assert_equal 'Antonio Carluccio', at.name
    assert_equal 'http://www.bbc.co.uk/food/chefs/antonio_carluccio', DefinitionReference.first.url
    assert_equal DefinitionReference.first, at.referents.first.references.first

    assert_equal 15, Recipe.count
    assert_equal 'Slow-cooked family stew with polenta', Recipe.first.title
    assert_equal 15, at.recipes.count # They should all be tagged with the
    assert_equal 17, Scraper.count # Launched scrapers for each recipe and the Next page
    assert Scraper.last.url.match('page=2')
    assert r=Recipe.find_by(title: 'Slow-cooked family stew with polenta')
    assert 'Serves 10', r.yield
    assert '1 to 2 hours', r.cook_time
    assert 'Less than 30 mins', r.prep_time

    assert_equal 13, show_tags(:Dish).count
    assert_equal 5, show_tags(:Occasion).count
    assert_equal 7, show_tags(:Source).count # including http://bbc.co.uk
    assert_equal 4, show_tags(:Course).count
    assert_equal 8, show_tags(:Diet).count
    assert_equal 2, show_tags(:Genre).count

  end

  test 'bbc_occasion_recipes_page' do
    url = 'http://www.bbc.co.uk/food/recipes/search?occasions[]=christmas'
    scraper = Scraper.assert url
    assert_equal 'bbc_occasion_recipes_page', scraper.handler.to_s
    scraper.perform_naked
    assert (occasion_tag = Tag.find_by( tagtype: Tag.typenum(:Occasion)))
    assert_equal 'Christmas', occasion_tag.name
    assert_equal 15, occasion_tag.recipes.count

    assert (Scraper.where(what: 'bbc_occasion_recipes_page').count > 10)
    assert Tag.where(tagtype: Tag.typenum(:Time)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Dish)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Occasion)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Author)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Source)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Course)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Diet)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Genre)).exists?

    assert Scraper.exists? what: 'bbc_dish_recipes_page'
    assert Scraper.exists? what: 'bbc_occasion_recipes_page'
    assert Scraper.exists? what: 'bbc_chef_recipes_page'
    assert Scraper.exists? what: 'bbc_programme_recipes_page'
    assert Scraper.exists? what: 'bbc_course_recipes_page'
    assert Scraper.exists? what: 'bbc_diet_recipes_page'
    assert Scraper.exists? what: 'bbc_cuisine_recipes_page'
  end

  test 'bbc_diet_recipes_page' do
    url = 'http://www.bbc.co.uk/food/recipes/search?diets[]=dairy_free'
    scraper = Scraper.assert url
    assert_equal :bbc_diet_recipes_page, scraper.handler
    scraper.perform_naked
    assert (diet_tag = Tag.find_by( tagtype: Tag.typenum(:Diet)))
    assert_equal 'dairy-free', diet_tag.name
    assert_equal 15, diet_tag.recipes.count

    assert_equal 10, Scraper.where(what: 'bbc_diet_recipes_page').count
    assert Tag.where(tagtype: Tag.typenum(:Dish)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Occasion)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Author)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Source)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Course)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Diet)).exists?
    assert Tag.where(tagtype: Tag.typenum(:Genre)).exists?

    assert Scraper.exists? what: 'bbc_dish_recipes_page'
    assert Scraper.exists? what: 'bbc_occasion_recipes_page'
    assert Scraper.exists? what: 'bbc_chef_recipes_page'
    assert Scraper.exists? what: 'bbc_programme_recipes_page'
    assert Scraper.exists? what: 'bbc_course_recipes_page'
    assert Scraper.exists? what: 'bbc_diet_recipes_page'
    assert Scraper.exists? what: 'bbc_cuisine_recipes_page'
  end

  test 'bbc_diet_recipes_page_2' do
    url = 'http://www.bbc.co.uk/food/recipes/search?page=2&diets[]=dairy_free'
    scraper = Scraper.assert url
    assert_equal :bbc_diet_recipes_page, scraper.handler
    scraper.perform_naked
    assert (diet_tag = Tag.find_by( tagtype: Tag.typenum(:Diet)))
    assert_equal 'dairy-free', diet_tag.name
    assert_equal 15, diet_tag.recipes.count

    assert_equal 2, Scraper.where(what: 'bbc_diet_recipes_page').count
    assert !(Scraper.exists? what: 'bbc_cuisine_recipes_page')
  end

  test 'bbc_scrape_tags' do
    # It's not terribly important which search-results page we fetch, but if based
    # on a category, it's a problem for accordion cracking on that category
    url = 'http://www.bbc.co.uk/food/recipes/search?occasions[]=fathers_day'
    scraper = Scraper.assert url, true, :bbc_scrape_tags
    assert_equal :bbc_scrape_tags, scraper.what.to_sym
    scraper.perform_naked

    assert Scraper.exists? what: 'bbc_dish_recipes_page'
    assert Scraper.exists? what: 'bbc_occasion_recipes_page'
    assert Scraper.exists? what: 'bbc_chef_recipes_page'
    assert Scraper.exists? what: 'bbc_course_recipes_page'
    assert Scraper.exists? what: 'bbc_diet_recipes_page'
    assert Scraper.exists? what: 'bbc_cuisine_recipes_page'
    assert Scraper.exists? what: 'bbc_programme_recipes_page'

    assert Tag.available? 'burger', :Dish
    assert Tag.available? 'Barbecue', :Occasion
    assert Tag.available? 'Nigel Slater', :Author
    assert Tag.available? 'desserts', :Course
    assert Tag.available? 'healthy', :Diet
    assert Tag.available? 'British', :Genre
    assert Tag.available? 'Nigellissima', :Source

  end

  test 'bbc_ingredient_home_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/candied_peel', false
    scraper.perform_naked
    # After scraping the page, there should be a SINGLE 'candied peel' tag, with corresponding expression, referent and ImageReference
    ing_tags = show_tags(:Ingredient)
    ing_tag = ing_tags.first
    assert_equal 1, ing_tags.count
    assert_equal 'candied peel', ing_tag.name
    ing_refs = Referent.where(type: 'IngredientReferent')
    ing_ref = ing_refs.first
    assert_equal ing_tag.referents, ing_refs
    assert_equal 1, ing_refs.count
    assert_equal 8, ImageReference.count
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_608/foods/c/candied_peel_16x9.jpg', ImageReference.first.url

    # Check that the referent got the image
    assert_equal ImageReference.first, ing_ref.picture

    # Rerun the scraper to ensure that no tags, etc. get created redundantly
    assert_nil Scraper.assert('http://www.bbc.co.uk/food/candied_peel', false)
    scraper.perform_naked
    # After scraping the page, there should be a SINGLE 'candied peel' tag, with corresponding expression, referent and ImageReference
    ing_tags = show_tags(:Ingredient)
    ing_tag = ing_tags.first
    assert_equal 1, ing_tags.count
    assert_equal 'candied peel', ing_tag.name
    ing_refs = Referent.where(type: 'IngredientReferent')
    ing_ref = ing_refs.first
    assert_equal ing_tag.referents, ing_refs
    assert_equal 1, ing_refs.count
    assert_equal 8, ImageReference.count
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_608/foods/c/candied_peel_16x9.jpg', ImageReference.first.url

    # Confirm that destroying the image removes the picture from the referent
    ImageReference.first.destroy
    ing_ref.reload
    assert_nil ing_ref.picture

    ing_ref.destroy
    assert_equal 0, Tag.first.expressions.count
    assert_equal 0, Tag.first.referents.count

  end

  test 'bbc_chefs_page' do
    url = 'http://www.bbc.co.uk/food/chefs'
    scraper = Scraper.assert url, false
    scraper.recur = true
    scraper.perform_naked
    assert_equal 9, Scraper.count
  end

  test 'bbc_chefs_atoz_page' do
    url = 'http://www.bbc.co.uk/food/chefs/by/letters/d,e,f'
    scraper = Scraper.assert url, false
    assert_equal scraper.handler, :bbc_chefs_atoz_page
    scraper.recur = true
    scraper.perform_naked
    assert_equal 57, Scraper.where(what: 'bbc_chef_home_page').count
    assert_equal 57, Scraper.where(what: 'bbc_chef_recipes_page').count
    scraper.perform_naked
    assert_equal 57, Scraper.where(what: 'bbc_chef_home_page').count
    assert_equal 57, Scraper.where(what: 'bbc_chef_recipes_page').count
  end

  test 'like_tags_different_pages' do
    tag1 = TagServices.define 'How to knead bread dough',
                              tagtype: 'Process',
                              page_link: 'http://www.bbc.co.uk/food/techniques/kneading'
    tag2 = TagServices.define 'How to knead bread dough',
                              tagtype: 'Process',
                              page_link: 'http://www.bbc.co.uk/food/techniques/how_to_knead_bread_dough'
    assert_equal 1, Tag.count
    assert_equal 2, DefinitionReference.count
  end

  test 'bbc_techniques_page' do
    url = 'http://www.bbc.co.uk/food/techniques'
    scraper = Scraper.assert url, false
    assert_equal scraper.handler, :bbc_techniques_page
    scraper.perform_naked

    process_tags = Tag.where tagtype: Tag.typenum(:Process)
    assert_equal 137, process_tags.count
    process_refs = Referent.where(type: 'ProcessReferent')
    assert_equal 137, process_refs.count
    assert_equal 132, DefinitionReference.count # No header defs, but two definitions for "How to knead bread dough"

    header_tag = Tag.find_by name: 'Preparing fruit and vegetables'
    assert_equal 19, TagServices.new(header_tag).child_referents.count
  end

  test 'bbc_technique_home_page' do
    url = 'http://www.bbc.co.uk/food/techniques/chopping_chillies'
    scraper = Scraper.assert url, true
    assert_equal scraper.handler, :bbc_technique_home_page
    scraper.perform_naked

    assert Reference.find_by( url: url, type: 'DefinitionReference')

    tech_tag = Tag.where(tagtype: Tag.typenum(:Process)).first
    assert_equal 'chopping chillies', tech_tag.name
    assert_equal url, tech_tag.referents.first.references.first.url

    tool_tags = Tag.where(tagtype: Tag.typenum(:Tool))
    assert_equal 2, tool_tags.count
    assert TagServices.new(tool_tags.first).suggests? tech_tag

    author_tag = Tag.where(tagtype: Tag.typenum(:Author)).first
    assert_equal 'Madhur Jaffrey', author_tag.name
    assert_equal 'http://www.bbc.co.uk/food/chefs/madhur_jaffrey', author_tag.referents.first.references.first.url
    # Author links to process
    TagServices.new(author_tag).suggests? tech_tag

    assert_equal 23, Recipe.count
    assert_equal 24, Scraper.count
  end

  test 'bbc_recipes_page' do
    User.super_id = (User.find(User.super_id) rescue User.create(email: 'mesuper@bogus.com')).id
    url = 'http://www.bbc.co.uk/food/recipes'
    scraper = Scraper.assert url, true
    assert_equal :bbc_recipes_page, scraper.handler
    scraper.perform_naked

    assert_equal 9, List.count
    assert_equal 10, Scraper.count
    assert_equal 9, ImageReference.count
  end

  test 'bbc_collection_home_page' do
    url = 'http://www.bbc.co.uk/food/collections/healthy_fish_recipes'
    scraper = Scraper.assert url, false
    assert_equal scraper.handler, :bbc_collection_home_page
    scraper.perform_naked

    list = List.first
    assert_equal 'Healthy fish recipes (BBC Food)', list.title
    assert_equal 'Light, nutritious and delicious fish dishes make a healthy supper in minutes.', list.description
    assert_equal 21, list.entity_count
  end

  test 'bbc_chef_home_page' do
    url = 'http://www.bbc.co.uk/food/chefs/antonio_carluccio'
    scraper = Scraper.assert url, false
    assert_equal scraper.handler, :bbc_chef_home_page
    scraper.perform_naked
    dr = DefinitionReference.first
    assert_equal url, dr.url

    Rails.logger.info 'Tags gleaned: ' + Tag.all.map(&:name).join(', ')
    assert_equal 6, Tag.count
    ats = Tag.where tagtype: Tag.typenum(:Author)
    assert_equal 1, ats.count
    at = ats.first
    assert_equal 'Antonio Carluccio', at.name
    assert_equal 1, AuthorReferent.count
    ar = AuthorReferent.first
    assert_equal dr, ar.references.first
    assert_equal ar, at.referents.first
    assert_equal at, ar.tags.first
    assert ar.description.match('Antonio Carluccio is a leading authority on Italian cooking')
  end

  test 'bbc_programme_home_page' do
    url = 'http://www.bbc.co.uk/food/programmes/b04gtx26'
    scraper = Scraper.assert url, true
    assert_equal scraper.handler, :bbc_programme_home_page
    scraper.save
    scraper.perform_naked
    # Check for "find all recipes" link
    assert Scraper.find_by(what: 'bbc_programme_recipes_page', url: 'http://www.bbc.co.uk/food/recipes/search?programmes[]=b04gtx26')
    source_tags = show_tags(:Source)
    source_tag = source_tags.first
    assert_equal 'A Taste of Britain', source_tag.name

    # Ensure the existence of both this page and the Programme's home page on the bbc
    assert Reference.find_by(type: 'DefinitionReference', url: 'http://www.bbc.co.uk/food/programmes/b04gtx26')
    assert Reference.find_by(type: 'DefinitionReference', url: 'http://www.bbc.co.uk/programmes/b04gtx26')

    source_ref = source_tag.referents.first
    assert_equal 2, source_ref.references.count
    assert source_ref.references.where(type: 'DefinitionReference', url: 'http://www.bbc.co.uk/food/programmes/b04gtx26').exists?
    assert source_ref.references.where(type: 'DefinitionReference', url: 'http://www.bbc.co.uk/programmes/b04gtx26').exists?

    assert source_ref.description.match('Food programme exploring specialities from around Britain.')
    assert_equal 'http://ichef.bbci.co.uk/images/ic/608x342/p025h6sj.jpg', source_ref.picurl

    # Check that the author's name got defined, and linked into our referent as an association
    auth_refs = source_ref.author_referents
    auth_ref = auth_refs.first
    # assert_equal 1, auth_refs.count
    assert source_ref.suggests?(auth_ref)
    assert source_ref.author_referents.include?(auth_ref)
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_1x1_95/chefs/brian_turner_1x1.jpg', auth_ref.picurl
    assert_equal 'Brian Turner', auth_ref.name
    assert_equal 'http://www.bbc.co.uk/food/chefs/brian_turner', auth_ref.references.where(type: 'DefinitionReference').first.url
  end

  test 'bbc_nigella_home_page' do
    url = 'http://www.bbc.co.uk/food/chefs/nigella_lawson'
    scraper = Scraper.assert url, true
    assert_equal scraper.handler, :bbc_chef_home_page
    scraper.save
    scraper.perform_naked

    chef_tag = show_tags(:Author).first
    assert_equal 'Nigella Lawson', chef_tag.name
    assert (chef_ref = chef_tag.referents.first)
    assert_equal 2, chef_ref.references.count
    assert_equal 'http://www.bbc.co.uk/food/chefs/nigella_lawson', chef_ref.references.first.url
    assert_equal 'http://www.nigella.com/', chef_ref.references.last.url
  end

  test 'bbc_recipe_home_page' do
    url = 'http://www.bbc.co.uk/food/recipes/lemon_and_ricotta_tart_44080'
    r1 = CollectibleServices.find_or_create({ url: url }, { 'Title' => 'Lemon and ricotta tart' }, Recipe)
    scraper = Scraper.assert url, false
    scraper.perform_naked

    assert_equal 1, Recipe.count
    r = Recipe.first
    assert_equal r, r1
    assert_equal 'Lemon and ricotta tart', r.title
    assert_equal 'less than 30 mins', r.prep_time
    assert_equal '30 mins to 1 hour', r.cook_time
    assert_equal 'Serves 8', r.yield
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_448/recipes/lemon_and_ricotta_tart_44080_16x9.jpg', r.picurl
    assert r.description.match('This easy lemon tart is delicious')

    diet_tags = Tag.where(tagtype: Tag.typenum(:Diet))
    assert_equal 1, diet_tags.count
    assert_equal 'Vegetarian', diet_tags.first.name
    assert_equal r, diet_tags.first.recipes.first

    author_tags = Tag.where(tagtype: 7)
    assert_equal 1, author_tags.count
    assert_equal 'Antonio Carluccio', author_tags.first.name

    ingredient_tags = Tag.where(tagtype: 4)
    assert_equal 8, ingredient_tags.count
    tag_names = %w{ puff\ pastry plain\ flour eggs ricotta lemon mascarpone candied\ peel caster\ sugar }
    ingredient_tags.each { |it|
      assert tag_names.include?(it.name)
      assert (it.recipes.to_a == [r])
    }
  end

  test 'bbc_seasons_atoz_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/seasons', true
    scraper.save
    scraper.perform_naked
    stags = show_tags :Occasion
    assert_equal 12, stags.count
    assert_equal 'January', stags.first.name

    assert_equal 12, Reference.where(type: 'ImageReference').count

    assert_equal 13, Scraper.count
    assert_equal 'http://www.bbc.co.uk/food/seasons/december', Scraper.last.url
  end

  test 'bbc_seasons_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/seasons', true
    scraper.perform_naked

    assert_equal 12, Tag.where(tagtype: 8).count
    assert_equal 'January', Tag.where(tagtype: 8).first.name

    assert_equal 'http://www.bbc.co.uk/food/seasons/january', DefinitionReference.first.url
    assert_equal 12, DefinitionReference.count
    assert_equal 12, ImageReference.count
    assert_equal 12, OccasionReferent.count
    occr = OccasionReferent.first
    assert_equal ImageReference.first, occr.picture
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_235/seasons/january_16x9.jpg', occr.picurl
  end

  test 'bbc_dish_home_page' do
    # Scrape the 'sauce' page and confirm results
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/sauce', :bbc_dish_home_page, true
    assert_equal :bbc_dish_home_page, scraper.what.to_sym
    scraper.save
    scraper.perform_naked

    dish_tags = Tag.where(tagtype: Tag.typenum(:Dish))
    assert_equal 35, dish_tags.count
    dish_tag = dish_tags.first
    assert_equal 'Sauces', dish_tag.name

    # 34 child dishes
    assert_equal 34, dish_tag.referents.first.children.count

    # ---- 1 definition page: this one
    assert_equal 1, dish_tag.referents.first.references.count

    # ---- 14 recipes in 5 accordions
    assert_equal 15, Recipe.count
    assert_equal 15, dish_tag.taggings.count
    courses = show_tags :Course
    assert_equal 5, courses.count
    sides = courses.first
    assert_equal 1, sides.recipes.count

    # Confirm that the first recipe under the "side dish" tab is tagged with both 'sauces' and 'side dish'
    r = Recipe.first
    assert r.tags.include?(dish_tag), "Recipe doesn't have Sauces tag"
    course_tag = show_tags(:Course).first
    assert_equal course_tag.name, 'side dishes'
    assert r.tags.include?(course_tag), "Recipe doesn't have side dish tag"

    assert 1, Scraper.where(what: 'bbc_dish_recipes_page').count
  end

  test 'bbc_cuisine_home_page' do
    # Scrape the 'January' page and confirm results
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/cuisines/italian', false
    assert_equal :bbc_cuisine_home_page, scraper.handler
    scraper.recur = true
    scraper.save
    scraper.perform_naked

    genre_tags = show_tags(:Genre)
    assert_equal 1, genre_tags.count
    genre_tag = genre_tags.first
    assert_equal 'Italian', genre_tag.name

    # ----- 14 associated dishes
    assert_equal 14, show_tags(:Dish).count
    assert_equal 14, genre_tag.referents.first.dish_referents.count

    # ---- 22 associated ingredients
    assert_equal 33, show_tags(:Ingredient).count
    assert_equal 33, genre_tag.referents.first.ingredient_referents.count

    # ---- 6 associated authors
    assert Tag.where(name: 'Angela Hartnett', tagtype: Tag.typenum(:Author)).exists?

    # ---- 3 definition pages, including this one
    assert_equal 3, genre_tag.referents.first.references.count

    # ---- 40 recipes in 8 accordions
    assert_equal 40, Recipe.count
    assert_equal 40, genre_tag.taggings.count
    courses = show_tags :Course
    assert_equal 8, courses.count
    mains = courses.first
    assert_equal 5, mains.recipes.count

    # Confirm that the first recipe under the "Main courses" tab is tagged with both 'Italian' and 'Main course'
    r = Recipe.first
    assert r.tags.include?(genre_tag), "Recipe doesn't have Italian tag"
    course_tag = Tag.where(tagtype: Tag.typenum(:Course)).first
    assert_equal course_tag.name, 'main course'
    assert r.tags.include?(course_tag), "Recipe doesn't have course tag"

  end

  test 'bbc_season_home_page' do
    # Scrape the 'January' page and confirm results
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/seasons/january', false
    # We're going to go through this twice, the second time to confirm that redundancy was avoided
    scraper.perform_naked
    assert_equal 1, Tag.where(tagtype: 8).count
    month_tag = Tag.where(tagtype: 8).first
    assert_equal 'January', month_tag.name
    # ---- 36 recipes
    assert_equal 36, Recipe.count
    assert_equal 36, month_tag.taggings.count
    # ---- 22 seasonal ingredients
    assert_equal 1, OccasionReferent.count
    assert_equal 22, Tag.where(tagtype: 4).count
    assert_equal 22, month_tag.referents.first.ingredient_referents.count

    # Confirm that the first recipe under the "Main courses" tab is tagged with both 'January' and 'Main courses'
    r = Recipe.first
    assert r.tags.include?(month_tag), "Recipe doesn't have month tag"
    course_tag = Tag.where(tagtype: Tag.typenum(:Course)).first
    assert_equal course_tag.name, 'main course'
    assert r.tags.include?(course_tag), "Recipe doesn't have course tag"

    # Second time around...
    scraper.perform_naked
    assert_equal 1, Tag.where(tagtype: 8).count
    month_tag = Tag.where(tagtype: 8).first
    assert_equal 'January', month_tag.name
    # Scrape the 'January' page and confirm results
    # ---- 32 recipes
    assert_equal 36, Recipe.count
    assert_equal 36, month_tag.taggings.count
    # ---- 22 seasonal ingredients
    assert_equal 1, OccasionReferent.count
    assert_equal 22, Tag.where(tagtype: 4).count
    assert_equal 22, month_tag.referents.first.ingredient_referents.count

    # Caught all the accordion tabs?
    course_tags = show_tags :Course
    assert_equal 8, course_tags.count
    mains = course_tags.first
    assert_equal 5, mains.recipes.count
  end

  test 'bbc_cuisines_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/cuisines', true
    assert_equal :bbc_cuisines_page, scraper.what.to_sym
    scraper.perform_naked

    tagtype = Tag.typenum :Genre
    assert_equal 20, Tag.where(tagtype: tagtype).count
    assert_equal 'African', Tag.where(tagtype: tagtype).first.name

    assert_equal 'http://www.bbc.co.uk/food/cuisines/african', DefinitionReference.first.url
    assert_equal 20, DefinitionReference.count
    assert_equal 20, ImageReference.count
    assert_equal 20, GenreReferent.count

    occr = GenreReferent.first
    assert_equal ImageReference.first, occr.picture
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_235/cuisines/african_16x9.jpg', occr.picurl

    assert_equal 21, Scraper.count
    assert_equal 20, Scraper.where(what: 'bbc_cuisine_home_page').count
  end

  test 'bbc_ingredients_by_letter' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/ingredients/by/letter/o', true
    scraper.perform_naked
    assert_equal 21, Scraper.count
    assert !Scraper.where('url LIKE ?', '%related-foods%').exists?
    assert_equal 20, show_tags('Ingredient').count
  end

  test 'bbc_candied_peel_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/candied_peel', true
    scraper.perform_naked
    assert_equal 8, ImageReference.count
    assert_equal 1, DefinitionReference.count
    assert_equal 1, show_tags(:Ingredient).count
    assert_equal 1, show_tags(:Source).count
    assert_equal 8, show_tags(:Author).count
    courses = show_tags(:Course)
    assert_equal 2, courses.count
    assert_equal 'desserts', courses.first.name
    assert_equal 'cakes and baking', courses.last.name

    assert_equal 1, IngredientReferent.count
    assert_equal 2, CourseReferent.count

    r = Recipe.first
    assert_equal 'Lemon and ricotta tart', r.title
    assert_equal 'http://www.bbc.co.uk/food/recipes/lemon_and_ricotta_tart_44080', r.url
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_88/recipes/lemon_and_ricotta_tart_44080_16x9.jpg', r.picurl
    assert r.tags.exists?(name: 'Antonio Carluccio')
    assert r.tags.exists?(name: 'desserts')

    # Caught all the accordion tabs?
    courses = Tag.where(tagtype: Tag.typenum(:Course))
    assert_equal 2, courses.count
    assert_equal 'desserts', courses.first.name
    assert_equal 5, courses.first.recipes.count

  end

  test 'bbc_cheese_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/cheese', true
    scraper.perform_naked
    cheese_tag = Tag.where(normalized_name: 'cheese', tagtype: Tag.typenum(:Ingredient)).first
    assert_equal 35, TagServices.new(cheese_tag).child_referents.count
    assert_equal 6, show_tags(:Dish).count
    assert_equal 7, show_tags(:Course).count
    assert_equal 32, Recipe.count
  end

  test 'bbc_occasions_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/occasions', true
    assert_equal :bbc_occasions_page, scraper.handler
    scraper.save
    scraper.perform_naked
    assert_equal 31, show_tags(:Occasion).count
    assert_equal 32, Scraper.count
  end

  test 'bbc_occasion_home_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/occasions/passover', true
    scraper.data = { Occasion: 'Passover' }
    assert_equal :bbc_occasion_home_page, scraper.handler
    scraper.save
    scraper.perform_naked

    assert (occ_tag = Tag.find_by( name: 'Passover', tagtype: Tag.typenum(:Occasion)))
    assert_equal 17, occ_tag.recipes.count
    assert_equal 17, Recipe.count
    ing_tags = show_tags(:Ingredient)
    assert_equal 5, ing_tags.count

    assert TagServices.new(occ_tag).suggests? ing_tags.first
    assert TagServices.new(occ_tag).suggests? ing_tags.last

    assert (occ_ref = occ_tag.referents.first)
    assert_equal 5, occ_ref.ingredient_referents.count
    assert_equal 24, Scraper.count # Including the initial scraper
    assert_equal 1, Scraper.where(what: 'bbc_occasion_recipes_page').count
    assert_equal 17, Scraper.where(what: 'bbc_recipe_home_page').count
  end

  test 'bbc_Christmas_home_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/occasions/christmas', true
    assert_equal :bbc_occasion_home_page, scraper.handler
    scraper.save
    scraper.perform_naked

    assert (occ_tag = Tag.find_by( name: 'Christmas', tagtype: Tag.typenum(:Occasion)))
    assert_equal 45, occ_tag.recipes.count
    assert_equal 45, Recipe.count
    assert_equal 23, show_tags(:Dish).count
    assert_equal 17, show_tags(:Ingredient).count

    assert_equal 8, show_tags(:Course).count

    assert (occ_ref = occ_tag.referents.first)
    assert_equal 17, occ_ref.ingredient_referents.count
    assert_equal 23, occ_ref.dish_referents.count
    assert_equal 1, Scraper.where(what: 'bbc_occasion_recipes_page').count
    assert_equal 45, Scraper.where(what: 'bbc_recipe_home_page').count
    assert_equal 23, Scraper.where(what: 'bbc_dish_home_page').count
    assert_equal 17, Scraper.where(what: 'bbc_collection_home_page').count

    assert_equal 17, show_tags(:List).count
  end
end
