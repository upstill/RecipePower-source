class ReferenceServices

  attr_accessor :reference

  delegate :url, :to => :reference # , :reference_type

  def initialize(reference)
    self.reference = reference
  end


  # Assert an image, linking back to a referent
  def self.assert_image_for_referent(uri, tag_or_referent)
      refs = Reference::ImageReference.find_or_initialize uri
      if refs.first.errors.empty?
          rft =
              case tag_or_referent
                  when Tag
                      Referent.express tag_or_referent
                  else
                      tag_or_referent
              end
          if rft
              refs.each { |ref|
                  # ref.assert tag_or_referent
                  ref.referents << rft unless ref.referents.exists?(id: rft.id)
                  ref.save
              }
          end
      end
      refs.first
  end

  def self.convert_references klass=nil
    puts DefinitionReference.all.collect { |ref|
           pr = DefinitionPageRef.fetch ref.url
           pr.url if pr.bad?
         }
  end

  # Convert ALL references to STI specification
  def self.convert_to_sti n=-1
    set = Reference.where(type: "Reference")[0..n].each do |ref|
      ref.type = ref.typesym.to_s+"Reference"
      ref.save # ref.ping
    end
  end

  # Run benchmarks on Reference and PageRef activities
  def self.time_lookup ix=1
    urls = [
        'http://www.bento.com/rf_ok.html',
        'http://www.bento.com/rf_temp.html',
        'http://www.bento.com/rf_yaki.html',
        'http://www.bento.com/rf_unagi.html',
        'http://www.bento.com/rf_nabe.html',
        'http://www.bento.com/fexp-labels.html',
        'http://www.bento.com/trt-shabu.html',
        'http://www.bento.com/trt-tonkatsu.html',
        'http://www.nytimes.com/2009/05/20/dining/203frex.html',
        'http://www.bento.com/tr-mich.html',
        'http://www.cavolettodibruxelles.it/2008/07/la-torta-di-ciliege',
        'http://www.theguardian.com/lifeandstyle/2013/jun/13/how-to-make-perfect-cucumber-sandwiches',
        'http://www.nytimes.com/recipes/1015851/spanish-tortilla-with-tomato-pepper-salad.html',
        'http://zoebakes.com/2013/05/01/cherry-chocolate-cake/',
        'http://www.davidlebovitz.com/2009/07/sardine-pate/',
        'http://www.bbcgoodfood.com/recipes/420616/rhubarb-crumble',
        'http://www.foodnetwork.com/recipes/mario-batali/pollo-alla-romana-roman-style-chicken-recipe.html?soc=sharingfb',
        'http://www.foodnetwork.com/recipes/mario-batali/pollo-alla-romana-roman-style-chicken-recipe/index.html?soc=sharingfb',
        'http://www.haydenflourmills.com/blog/2013/9/26/tangy-miso-farro-salad',
        'http://haydenflourmills.com/blog/2013/9/26/tangy-miso-farro-salad',
        'http://spoonful.com/recipes/persimmon-pudding',
        'http://www.foodandwine.com/recipes/whole-wild-salmon-fillet-with-mustard-sauce',
        'http://www.foodandwine.com/recipes/flaugnarde-with-pears',
        'http://www.seriouseats.com/recipes/2011/11/mock-apple-pie-ritz-cracker-recipe.html',
        'http://www.tasteofbeirut.com/2011/10/persian-cheese-panir/',
        'http://oggi-icandothat.blogspot.com/2008/02/robert-rodriguezs-puerco-pibil.html',
        'http://www.theguardian.com/lifeandstyle/wordofmouth/2011/oct/20/how-to-cook-perfect-tarte-tatin',
        'http://www.guardian.co.uk/lifeandstyle/wordofmouth/2011/oct/20/how-to-cook-perfect-tarte-tatin',
        'http://ricette.giallozafferano.it/Involtini-di-tacchino-ripieni-con-funghi-Champignon.html',
        'http://www.theguardian.com/lifeandstyle/2008/dec/06/side-dishes-christmas-recipes?recipetitle=Roasted+pumpkin+wedges+with+chestnut%2C+cinnamon+%26+fresh+bay+leaves+',
        'http://www.guardian.co.uk/lifeandstyle/2008/dec/06/side-dishes-christmas-recipes?recipetitle=Roasted+pumpkin+wedges+with+chestnut%2C+cinnamon+%26+fresh+bay+leaves+',
        'http://ricette.giallozafferano.it/Mostarda-di-Cremona.html',
        'http://www.theguardian.com/uk/2006/nov/19/christmas.foodanddrink1?recipetitle=Turkey+breast+joint+with+sloe+gin+cranberry+sauce',
        'http://www.guardian.co.uk/uk/2006/nov/19/christmas.foodanddrink1?recipetitle=Turkey+breast+joint+with+sloe+gin+cranberry+sauce',
        'http://www.theguardian.com/lifeandstyle/2008/apr/27/recipes.foodanddrink4?recipetitle=Ricotta+cake',
        'http://www.guardian.co.uk/lifeandstyle/2008/apr/27/recipes.foodanddrink4?recipetitle=Ricotta+cake',
        'http://smittenkitchen.com/blog/2011/10/apple-pie-cookies/',
        'http://smittenkitchen.com/2011/10/apple-pie-cookies/',
        'http://www.chow.com/recipes/10680-chicken-chile-verde',
        'http://honest-food.net/2011/11/06/black-walnut-ice-cream/',
        'http://www.chow.com/recipes/29311-chocolate-lava-cake',
        'http://www.chow.com/recipes/14327-mocha-pudding-cake',
        'http://www.chow.com/recipes/10821-upside-down-banana-coffee-tart',
        'http://www.chow.com/recipes/29553-bacon-apple-and-blue-cheese-omelet',
        'http://honest-food.net/2011/10/31/pickled-cauliflower/',
        'http://food52.com/recipes/13098-diana-kennedy-s-carnitas',
        'http://food52.com/recipes/13098_diana_kennedys_carnitas',
        'http://huntergathercook.typepad.com/huntergathering_wild_fres/2011/10/espelette-chillis-perfect-peppers-and-basque-soup.html',
        'http://lacucinaitalianamagazine.com/recipe/shaved-fennel-red-onion-and--celery-salad-with-salami',
        'http://www.latimes.com/features/food/la-fo-pulquerias-rec1-20111110,0,5063589.story',
        'http://www.latimes.com/features/food/la-fo-pulquerias-rec2-20111110,0,5718950.story',
        'http://www.latimes.com/features/food/la-fo-pulquerias-rec4-20111110,0,7029672.story',
        'http://www.latimes.com/features/food/la-fo-pulquerias-rec3-20111110,0,6374311.story',
        'http://www.foodandwine.com/recipes/flaky-blood-orange-tart',
        'http://www.theguardian.com/lifeandstyle/australia-food-blog/2013/dec/20/kylie-kwongs-crispy-pork-belly-recipe',
        'http://www.theguardian.com/lifeandstyle/australia-food-blog/2013/dec/22/australian-christmas-feasts-guy-grossi',
        'http://www.davidlebovitz.com/2009/05/tart-au-citron-french-lemon-tart/',
        'http://frenchfood.about.com/od/desserts/r/lemontart.htm',
        'http://ohmyveggies.com/recipe-sriracha-snap-peas-with-red-pepper/',
        'http://www.foodandwine.com/recipes/cheesy-farro-and-tomato-risotto',
        'http://www.taste.com.au/recipes/26063/rich+almond+ricotta+cake',
        'http://honest-food.net/foraging-recipes/unusual-garden-veggies/cicerchia-bean-salad/',
        'http://honest-food.net/veggie-recipes/unusual-garden-veggies/cicerchia-bean-salad/',
        'http://food52.com/recipes/9949-carrot-gnocchi-with-butter-and-sage-sauce',
        'http://food52.com/recipes/9949_carrot_gnocchi_with_butter_and_sage_sauce',
        'http://www.tasteofbeirut.com/2011/07/swiss-chard-and-tahini-beoreg/',
        'http://www.chow.com/recipes/10883-croissant-and-armagnac-bread-pudding',
        'http://www.theguardian.com/lifeandstyle/2011/aug/19/courgette-recipes-yotam-ottolenghi?INTCMP=SRCH',
        'http://www.guardian.co.uk/lifeandstyle/2011/aug/19/courgette-recipes-yotam-ottolenghi?INTCMP=SRCH',
        'http://www.theguardian.com/lifeandstyle/2010/oct/23/aubergine-with-herbs-recipe-ottolenghi',
        'http://www.guardian.co.uk/lifeandstyle/2010/oct/23/aubergine-with-herbs-recipe-ottolenghi',
        'http://www.tasteofbeirut.com/2011/08/moroccan-pancakes/',
        'http://www.tasteofbeirut.com/2011/08/ricotta-lebanese-style-areesheh/',
        'http://www.tasteofbeirut.com/2011/08/farmers-cheese-homemade-jeben-baladi/',
        'http://honest-food.net/2010/01/14/acorn-pasta-and-the-mechanics-of-eating-acorns/',
        'http://honest-food.net/foraging-recipes/acorns-nuts-and-other-wild-starches/acorn-soup/',
        'http://honest-food.net/veggie-recipes/acorns-nuts-and-other-wild-starches/acorn-soup/',
        'http://honest-food.net/2011/10/11/acorn-spaetzle/',
        'http://honest-food.net/foraging-recipes/acorns-nuts-and-other-wild-starches/black-walnut-parsley-pesto/',
        'http://honest-food.net/veggie-recipes/acorns-nuts-and-other-wild-starches/black-walnut-parsley-pesto/',
        'http://honest-food.net/foraging-recipes/unusual-garden-veggies/ancient-roman-fava-bean-dip/',
        'http://honest-food.net/veggie-recipes/unusual-garden-veggies/ancient-roman-fava-bean-dip/',
        'http://honest-food.net/2011/03/25/cardoon-gratin/',
        'http://honest-food.net/foraging-recipes/unusual-garden-veggies/cicerchia-bean-agnolotti/',
        'http://honest-food.net/veggie-recipes/unusual-garden-veggies/cicerchia-bean-agnolotti/',
        'http://honest-food.net/foraging-recipes/mushroom-recipes/wild-mushroom-pasta-with-a-gin-cream-sauce/',
        'http://honest-food.net/veggie-recipes/mushroom-recipes/wild-mushroom-pasta-with-a-gin-cream-sauce/',
        'http://honest-food.net/foraging-recipes/mushroom-recipes/red-wine-wild-mushroom-ragu/',
        'http://honest-food.net/veggie-recipes/mushroom-recipes/red-wine-wild-mushroom-ragu/',
        'http://honest-food.net/foraging-recipes/pumpkin-or-squash-spaetzle/',
        'http://honest-food.net/veggie-recipes/regular-garden-veggies/pumpkin-or-squash-spaetzle/',
        'http://honest-food.net/foraging-recipes/calabrian-hot-pepper-pasta/',
        'http://honest-food.net/veggie-recipes/regular-garden-veggies/calabrian-hot-pepper-pasta/',
        'http://honest-food.net/veggie-recipes/greens-and-herbs/strettine-an-italian-nettle-pasta/',
        'http://honest-food.net/2013/05/23/ramp-pasta-morels-recipe/',
        'http://honest-food.net/veggie-recipes/greens-and-herbs/ramp-pasta/',
        'http://honest-food.net/2012/12/12/snowball-cookies-recipe-walnut/',
        'http://honest-food.net/veggie-recipes/acorns-nuts-and-other-wild-starches/black-walnut-snowball-cookies/',
        'http://smittenkitchen.com/blog/2013/08/kale-salad-with-pecorino-and-walnuts/',
        'http://www.foodandwine.com/recipes/the-ultimate-southern-fried-chicken',
        'http://blog.countrytrading.co.nz/2014/01/01/how-to-make-nitrate-free-bacon-in-3-days/',
        'http://honest-food.net/wild-game/venison-recipes/venison-stews/spring-lamb-sugo/',
        'http://honest-food.net/wild-game/duck-goose-recipes/duck-and-goose-recipes-the-nasty-bits/duck-liver-ravioli/',
        'http://honest-food.net/2010/01/08/making-wild-game-tortelli/',
        'http://honest-food.net/foraging-recipes/greens-and-herbs/borage-and-ricotta-ravioli/',
        'http://honest-food.net/veggie-recipes/greens-and-herbs/borage-and-ricotta-ravioli/',
        'http://honest-food.net/veggie-recipes/greens-and-herbs/nettle-ravioli-northern-italian-style/',
        'http://honest-food.net/2010/11/19/pelmeni-and-the-eating-of-bears/',
        'http://honest-food.net/foraging-recipes/mushroom-recipes/honey-mushroom-pierogi/',
        'http://honest-food.net/veggie-recipes/mushroom-recipes/honey-mushroom-pierogi/',
        'http://www.theguardian.com/lifeandstyle/2008/dec/14/christmas-leftovers-recipes-locatelli-roux?recipetitle=Turkey+meatballs+in+sweet+and+sour+sauce',
        'http://www.guardian.co.uk/lifeandstyle/2008/dec/14/christmas-leftovers-recipes-locatelli-roux?recipetitle=Turkey+meatballs+in+sweet+and+sour+sauce',
        'http://www.theguardian.com/lifeandstyle/2008/dec/14/nigel-slater-turkey-christmas-recipe?recipetitle=Turkey+with+pistachio+and+apricot+stuffing',
        'http://www.guardian.co.uk/lifeandstyle/2008/dec/14/nigel-slater-turkey-christmas-recipe?recipetitle=Turkey+with+pistachio+and+apricot+stuffing',
        'http://www.theguardian.com/lifeandstyle/2008/dec/14/nigel-slater-turkey-christmas-recipe?recipetitle=Turkey+breast+steaks+with+prune+gravy',
        'http://www.guardian.co.uk/lifeandstyle/2008/dec/14/nigel-slater-turkey-christmas-recipe?recipetitle=Turkey+breast+steaks+with+prune+gravy',
        'http://www.theguardian.com/lifeandstyle/2007/nov/18/foodanddrink.recipes?recipetitle=Roast+turkey%2C+apricot+and+ginger+stuffing+',
        'http://www.guardian.co.uk/lifeandstyle/2007/nov/18/foodanddrink.recipes?recipetitle=Roast+turkey%2C+apricot+and+ginger+stuffing+',
        'http://www.theguardian.com/lifeandstyle/2007/nov/18/recipes.foodanddrink2?recipetitle=Turkey+fricassee+with+porcini',
        'http://www.guardian.co.uk/lifeandstyle/2007/nov/18/recipes.foodanddrink2?recipetitle=Turkey+fricassee+with+porcini',
        'http://www.theguardian.com/lifeandstyle/2007/nov/18/recipes.foodanddrink2?recipetitle=Turkey+stuffed+with+chestnuts',
        'http://www.guardian.co.uk/lifeandstyle/2007/nov/18/recipes.foodanddrink2?recipetitle=Turkey+stuffed+with+chestnuts',
        'http://www.theguardian.com/lifeandstyle/2007/nov/18/recipes.foodanddrink2?recipetitle=Turkey+stuffed+with+brussels+sprouts',
        'http://www.guardian.co.uk/lifeandstyle/2007/nov/18/recipes.foodanddrink2?recipetitle=Turkey+stuffed+with+brussels+sprouts',
        'http://www.theguardian.com/uk/2005/dec/24/christmas.foodanddrink?recipetitle=Devilled+turkey',
        'http://www.guardian.co.uk/uk/2005/dec/24/christmas.foodanddrink?recipetitle=Devilled+turkey',
        'http://www.theguardian.com/lifeandstyle/2001/dec/09/foodanddrink.recipes1?recipetitle=Traditional+roast+turkey',
        'http://www.guardian.co.uk/lifeandstyle/2001/dec/09/foodanddrink.recipes1?recipetitle=Traditional+roast+turkey',
        'http://www.theguardian.com/lifeandstyle/2001/may/13/foodanddrink.recipes1?recipetitle=Turkey+meatloaf',
        'http://www.guardian.co.uk/lifeandstyle/2001/may/13/foodanddrink.recipes1?recipetitle=Turkey+meatloaf',
        'http://www.theguardian.com/lifeandstyle/2010/dec/18/christmas-starters-stuffing-recipes?recipetitle=Pear+and+celeriac+stuffing',
        'http://www.guardian.co.uk/lifeandstyle/2010/dec/18/christmas-starters-stuffing-recipes?recipetitle=Pear+and+celeriac+stuffing',
        'http://www.theguardian.com/lifeandstyle/2009/dec/27/nigel-slater-chestnut-mincemeat-recipes?recipetitle=PARSNIP%2C+CHESTNUT+AND+MUSHROOM+CASSEROLE',
        'http://www.guardian.co.uk/lifeandstyle/2009/dec/27/nigel-slater-chestnut-mincemeat-recipes?recipetitle=PARSNIP%2C+CHESTNUT+AND+MUSHROOM+CASSEROLE',
        'http://www.theguardian.com/lifeandstyle/2001/jun/10/foodanddrink.recipes3?recipetitle=Thai+chicken+salad',
        'http://www.guardian.co.uk/lifeandstyle/2001/jun/10/foodanddrink.recipes3?recipetitle=Thai+chicken+salad',
        'http://www.theguardian.com/lifeandstyle/2004/feb/15/foodanddrink.recipes?recipetitle=Grilled+pork+salad',
        'http://www.guardian.co.uk/lifeandstyle/2004/feb/15/foodanddrink.recipes?recipetitle=Grilled+pork+salad',
        'http://www.theguardian.com/lifeandstyle/2004/feb/22/foodanddrink.shopping?recipetitle=Roast+pork+belly+with+five-spice+rub',
        'http://www.guardian.co.uk/lifeandstyle/2004/feb/22/foodanddrink.shopping?recipetitle=Roast+pork+belly+with+five-spice+rub',
        'http://www.theguardian.com/lifeandstyle/2004/may/16/foodanddrink.recipes',
        'http://www.guardian.co.uk/lifeandstyle/2004/may/16/foodanddrink.recipes',
        'http://www.theguardian.com/lifeandstyle/wordofmouth/2008/nov/25/recipe-fish?recipetitle=Smoked+haddock+and+leek+risotto',
        'http://www.guardian.co.uk/lifeandstyle/wordofmouth/2008/nov/25/recipe-fish?recipetitle=Smoked+haddock+and+leek+risotto',
        'http://www.chow.com/recipes/13580-braised-brussels-sprouts',
        'http://honest-food.net/wild-game/duck-goose-recipes/soups-stews-and-broths/sugo-danatra-wild-duck-ragu/',
        'http://honest-food.net/wild-game/duck-goose-recipes/soups-stews-and-broths/ducky-tomato-sauce-for-pasta/',
        'http://www.cookinglight.com/food/recipe-finder/myplate-inspired-beef-recipes-00412000081047/',
        'http://www.bonappetit.com/recipe/brussels-sprouts-kimchi',
        'http://www.cookinglight.com/food/recipe-finder/myplate-inspired-quick-easy-00412000081022/',
        'http://www.tasteofbeirut.com/2013/12/milk-and-bread-pudding-ashtaliyeh/',
        'http://www.myrecipes.com/recipe/chicken-breasts-with-tomatoes-olives-10000001918514/',
        'http://www.bonappetit.com/recipe/spicy-pork-and-mustard-green-soup',
        'http://www.dailymail.co.uk/home/you/article-2086191/Recipe-Whole-lemon-almond-cake.html',
        'http://www.foodnetwork.com/recipes/ina-garten/perfect-roast-chicken-recipe.html',
        'http://www.buzzfeed.com/christinebyrne/roast-chicken-rules',
        'http://vegetarian.about.com/od/soupssalads/r/MisoSoup.htm',
        'http://www.theguardian.com/lifeandstyle/2009/apr/26/nigel-slater-salads?recipetitle=Sheep%27s+cheese%2C+sprouting+leaves+and+orange+salad',
        'http://www.guardian.co.uk/lifeandstyle/2009/apr/26/nigel-slater-salads?recipetitle=Sheep%27s+cheese%2C+sprouting+leaves+and+orange+salad',
        'http://www.theguardian.com/lifeandstyle/2009/may/10/spring-onions-recipes?recipetitle=Crystal+noodle+salad+with+pickled+ginger+and+lime',
        'http://www.guardian.co.uk/lifeandstyle/2009/may/10/spring-onions-recipes?recipetitle=Crystal+noodle+salad+with+pickled+ginger+and+lime',
        'http://www.theguardian.com/lifeandstyle/2010/dec/18/hot-sour-mushroom-soup-recipe?recipetitle=Yotam+Ottolenghi%27s+hot+and+sour+mushroom+soup+recipe',
        'http://www.guardian.co.uk/lifeandstyle/2010/dec/18/hot-sour-mushroom-soup-recipe?recipetitle=Yotam+Ottolenghi%27s+hot+and+sour+mushroom+soup+recipe',
        'http://www.theguardian.com/lifeandstyle/2010/nov/15/chicken-lemongrass-broth-recipe?recipetitle=Hot+and+sour+chicken+and+lemongrass+broth',
        'http://www.guardian.co.uk/lifeandstyle/2010/nov/15/chicken-lemongrass-broth-recipe?recipetitle=Hot+and+sour+chicken+and+lemongrass+broth',
        'http://www.theguardian.com/lifeandstyle/2010/mar/13/curry-laksa-recipe-yotam-ottolenghi?recipetitle=Yotam+Ottolenghi%27s+curry+laksa+recipe',
        'http://www.guardian.co.uk/lifeandstyle/2010/mar/13/curry-laksa-recipe-yotam-ottolenghi?recipetitle=Yotam+Ottolenghi%27s+curry+laksa+recipe',
        'http://www.theguardian.com/lifeandstyle/2010/jan/10/nigel-slater-greens-recipes?recipetitle=CAULIFLOWER+GRATIN+WITH+OAT+AND+SUNFLOWER+SEED+CRUST',
        'http://www.guardian.co.uk/lifeandstyle/2010/jan/10/nigel-slater-greens-recipes?recipetitle=CAULIFLOWER+GRATIN+WITH+OAT+AND+SUNFLOWER+SEED+CRUST',
        'http://www.theguardian.com/lifeandstyle/2004/dec/04/foodanddrink.shopping3?recipetitle=Brussels+sprouts+with+ginger+and+tomato',
        'http://www.guardian.co.uk/lifeandstyle/2004/dec/04/foodanddrink.shopping3?recipetitle=Brussels+sprouts+with+ginger+and+tomato',
        'http://www.theguardian.com/lifeandstyle/2005/dec/10/foodanddrink.recipes?recipetitle=Mashed+Brussels+sprouts+with+parmesan+and+cream',
        'http://www.guardian.co.uk/lifeandstyle/2005/dec/10/foodanddrink.recipes?recipetitle=Mashed+Brussels+sprouts+with+parmesan+and+cream',
        'http://www.theguardian.com/lifeandstyle/2007/sep/23/foodanddrink.features5?recipetitle=Brussels+sprouts+with+pancetta+and+chestnuts',
        'http://www.guardian.co.uk/lifeandstyle/2007/sep/23/foodanddrink.features5?recipetitle=Brussels+sprouts+with+pancetta+and+chestnuts',
        'http://www.theguardian.com/theguardian/2007/nov/24/weekend7.weekend3?recipetitle=Brussels+sprouts+and+tofu',
        'http://www.guardian.co.uk/theguardian/2007/nov/24/weekend7.weekend3?recipetitle=Brussels+sprouts+and+tofu',
        'http://lacucinaitalianamagazine.com/recipe/bread-and-prune-gnocchi-with-plum-brandy-and-pork-',
        'http://www.theguardian.com/lifeandstyle/2008/dec/06/side-dishes-christmas-recipes?recipetitle=Pan-fried+brussels+sprouts+and+shallots+with+pomegranate+%26+purple+basil+',
        'http://www.guardian.co.uk/lifeandstyle/2008/dec/06/side-dishes-christmas-recipes?recipetitle=Pan-fried+brussels+sprouts+and+shallots+with+pomegranate+%26+purple+basil+',
        'http://www.theguardian.com/lifeandstyle/2009/nov/08/christmas-recipe-top-chefs-tips?recipetitle=Jason+Atherton%3A+Brussels+sprout+and+chestnut+risotto',
        'http://www.guardian.co.uk/lifeandstyle/2009/nov/08/christmas-recipe-top-chefs-tips?recipetitle=Jason+Atherton%3A+Brussels+sprout+and+chestnut+risotto',
        'http://www.theguardian.com/lifeandstyle/2010/dec/04/christmas-standby-recipes-angela-hartnett?recipetitle=Brussels+sprout+and+potato+bubble+and+squeak',
        'http://www.guardian.co.uk/lifeandstyle/2010/dec/04/christmas-standby-recipes-angela-hartnett?recipetitle=Brussels+sprout+and+potato+bubble+and+squeak',
        'http://www.theguardian.com/lifeandstyle/2010/nov/13/brussels-sprouts-recipes-fearnley-whittingstall?recipetitle=Creamed+brussels+sprouts+with+bacon',
        'http://www.guardian.co.uk/lifeandstyle/2010/nov/13/brussels-sprouts-recipes-fearnley-whittingstall?recipetitle=Creamed+brussels+sprouts+with+bacon',
        'http://www.theguardian.com/lifeandstyle/2010/nov/13/brussels-sprouts-recipes-fearnley-whittingstall?recipetitle=Roasted+brussels+sprouts+with+shallots+and+caraway+seeds',
        'http://www.guardian.co.uk/lifeandstyle/2010/nov/13/brussels-sprouts-recipes-fearnley-whittingstall?recipetitle=Roasted+brussels+sprouts+with+shallots+and+caraway+seeds',
        'http://www.theguardian.com/lifeandstyle/2008/mar/29/recipe.foodanddrink?recipetitle=The+new+vegetarian%3A+Poached+baby+vegetables+with+caper+mayonnaise',
        'http://www.guardian.co.uk/lifeandstyle/2008/mar/29/recipe.foodanddrink?recipetitle=The+new+vegetarian%3A+Poached+baby+vegetables+with+caper+mayonnaise',
        'http://www.theguardian.com/lifeandstyle/2008/jun/28/recipe.foodanddrink?recipetitle=The+new+vegetarian%3A+Gado+gado',
        'http://www.guardian.co.uk/lifeandstyle/2008/jun/28/recipe.foodanddrink?recipetitle=The+new+vegetarian%3A+Gado+gado',
        'http://www.theguardian.com/lifeandstyle/2008/dec/03/weekly-recipe-soup?recipetitle=White+bean+and+winter+greens+soup',
        'http://www.guardian.co.uk/lifeandstyle/2008/dec/03/weekly-recipe-soup?recipetitle=White+bean+and+winter+greens+soup',
        'http://www.bonappetit.com/recipe/brown-butter-polenta-cake-with-maple-caramel',
        'http://www.foodandwine.com/recipes/stuffed-kale-with-bulgur-tabbouleh-and-lime-yogurt-dip',
        'http://www.epicurious.com/recipes/food/views/Lentil-Salad-with-Balsamic-Vinaigrette-101018',
        'http://www.theguardian.com/lifeandstyle/2011/feb/19/recipes-from-nopi-yotam-ottolenghi?recipetitle=Raw+Brussels+sprouts+with+oyster+mushrooms+and+quail+eggs',
        'http://www.guardian.co.uk/lifeandstyle/2011/feb/19/recipes-from-nopi-yotam-ottolenghi?recipetitle=Raw+Brussels+sprouts+with+oyster+mushrooms+and+quail+eggs',
        'http://www.theguardian.com/lifeandstyle/2011/nov/11/spiced-lamb-shanks-recipe-ottolenghi',
        'http://www.guardian.co.uk/lifeandstyle/2011/nov/11/spiced-lamb-shanks-recipe-ottolenghi',
        'http://www.nytimes.com/recipes/11552/puntarella-with-green-anchoiade.html',
        'http://www.nytimes.com/recipes/11552/Puntarella-With-Green-Ancho239ade.html',
        'http://www.thechefproject.com//Assets/recipes/SriLanka.pdf',
        'http://nymag.com/listings/recipe/banoffee-pie/',
        'http://nymag.com/listings/recipe/swiss-chard-olive-oil/',
        'http://nymag.com/listings/recipe/artichoke-smash/',
        'http://nymag.com/listings/recipe/roasted-vegetables/',
        'http://nymag.com/listings/recipe/balsamic-glazed-duck/',
        'http://nymag.com/listings/recipe/salad-greens-butternut-squash/',
        'http://nymag.com/listings/recipe/devils-on-horseback/',
        'http://nymag.com/listings/recipe/sweet-potato-meringue-pie/',
        'http://nymag.com/listings/recipe/cauliflower-pears/',
        'http://nymag.com/listings/recipe/collard-greens/',
        'http://nymag.com/listings/recipe/cornbread-andouille-stuffing/',
        'http://nymag.com/listings/recipe/slow-cooked-roast-turkey/',
        'http://nymag.com/listings/recipe/oyster-chowder/',
        'http://www.nytimes.com/2011/11/16/dining/cauliflower-with-curry-butter-recipe.html',
        'http://readynutrition.com/resources/survival-food-series-3-ways-to-naturally-make-yeast_02032011/',
        'http://www.sfgate.com/cgi-bin/article.cgi?f=/c/a/2011/11/20/FDM41M0ORE.DTL&ao=2',
        'http://lacucinaitalianamagazine.com/recipe/mafaldine-with-rabbit-ragu',
        'http://lacucinaitalianamagazine.com/recipe/salmon-with-vodka--sauce-and-caviar',
        'http://lacucinaitalianamagazine.com/recipe/malloreddus-with-mixed-vegetables',
        'http://lacucinaitalianamagazine.com/recipe/cheese-fondue-with-grappa--and-walnut-bread',
        'http://lacucinaitalianamagazine.com/recipe/sea-bream-with-clams',
        'http://www.mariquita.com/recipes/agretti.html',
        'http://www.localforage.com/local_forage/2006/10/on_sunday_i_got.html',
        'http://blog.junbelen.com/2010/06/25/how-to-make-the-best-brioche-bread-pudding-tartine-recipe/',
        'http://www.theguardian.com/lifeandstyle/2010/nov/13/brussels-sprouts-recipes-fearnley-whittingstall?recipetitle=Brussels+sprout+salad',
        'http://www.guardian.co.uk/lifeandstyle/2010/nov/13/brussels-sprouts-recipes-fearnley-whittingstall?recipetitle=Brussels+sprout+salad',
        'http://lacucinaitalianamagazine.com/recipe/tartine-bakerys-panettone',
        'http://www.tasteofbeirut.com/2013/12/sweet-roll-kaak-alleeta/',
        'http://www.tasteofbeirut.com/2013/12/kibbeh-with-arnabiyeh-sauce-kibbeh-arnabiyeh/',
        'http://www.tasteofbeirut.com/2013/12/zaatar-flatbread-with-jreesh/',
        'http://www.tasteofbeirut.com/2013/12/date-sandwich-cake/',
        'http://lacucinaitalianamagazine.com/recipe/roman-style-salt-cod-in-a-seed-and-nut-crust--',
        'http://www.streetgourmetla.com/2011/11/cabrito-al-pastor-at-gran-san-carlos.html',
        'http://www.tasteofbeirut.com/2013/12/kibbeh-mortar-jurn/',
        'http://www.theguardian.com/lifeandstyle/2011/nov/25/prawn-okra-gumbo-potatocake-recipes',
        'http://www.guardian.co.uk/lifeandstyle/2011/nov/25/prawn-okra-gumbo-potatocake-recipes',
        'http://www.theguardian.com/lifeandstyle/2011/dec/02/christmas-party-food-yotam-ottolenghi',
        'http://www.guardian.co.uk/lifeandstyle/2011/dec/02/christmas-party-food-yotam-ottolenghi',
        'http://lacucinaitalianamagazine.com/recipe/sweet-torte-of-cannellini-beans-ricotta-and-cocoa-powder',
        'http://lacucinaitalianamagazine.com/recipe/creamy-sweet-polenta--with-cold-milk',
        'http://lacucinaitalianamagazine.com/recipe/rice-pudding',
        'http://nymag.com/restaurants/recipes/inseason/beets-2011-12/',
        'http://www.tasteofbeirut.com/2013/12/dried-fruit-salad-khoshaf-2/',
        'http://nymag.com/restaurants/recipes/inseason/sunchokes-2011-12/',
        'http://nymag.com/restaurants/recipes/inseason/brussels-sprouts-2011-11/',
        'http://nymag.com/restaurants/recipes/inseason/empire-apples-2011-11/',
        'http://nymag.com/restaurants/recipes/inseason/fennel-2011-10/',
        'http://nymag.com/restaurants/recipes/inseason/albacore-tuna-2011-10/',
        'http://www.theguardian.com/lifeandstyle/2011/dec/16/roasted-squash-stuffed-quince-recipes',
        'http://www.guardian.co.uk/lifeandstyle/2011/dec/16/roasted-squash-stuffed-quince-recipes',
        'http://lacucinaitalianamagazine.com/recipe/pirotecnica_2',
        'http://honest-food.net/2011/11/23/wild-turkey-risotto/',
        'http://www.britishlarder.co.uk/festive-christmas-pudding/#axzz1h0SM1ry4',
        'http://www.tasteofbeirut.com/2011/12/iraqi-taffy-mann-al-sama/',
        'http://www.tasteofbeirut.com/2011/12/bulgur-and-cumin-pate-kammounieh/',
        'http://www.tasteofbeirut.com/2011/12/eggplant-dip-mtabbal/',
        'http://honest-food.net/2011/12/01/sichuan-stir-fry-puffballs/',
        'http://honest-food.net/2011/12/04/braised-duck-legs-with-leeks/',
        'http://honest-food.net/2011/12/14/roast-snipe-and-slow-days/',
        'http://lacucinaitalianamagazine.com/recipe/panettone',
        'http://www.tasteofbeirut.com/2013/12/iraqi-cuisine-al-tabekh-al-3iraki-a-giveaway/',
        'http://www.tasteofbeirut.com/2013/11/areesheh-turnovers/',
        'http://www.tasteofbeirut.com/2013/11/areesheh-cheese/',
        'http://www.cooks.com/recipe/4m3l00w3/very-moist-chocolate-cake.html',
        'http://www.hungrycravings.com/2010/01/bergamot-orange-dreams.html',
        'http://www.nytimes.com/2009/05/20/dining/202frex.html',
        'http://blog.umamimart.com/2011/12/japanified-arancini/',
        'http://www.davidlebovitz.com/2006/12/moroccan-preser-1/',
        'http://honest-food.net/2010/02/04/preserving-lemons/',
        'http://www.davidlebovitz.com/2008/11/rosy-poached-quince/',
        'http://www.nytimes.com/2010/11/10/dining/10chefrex1.html',
        'http://www.bonappetit.com/recipes/2011/05/rainbow-cookies',
        'http://www.foodandwine.com/recipes/grilled-lamb-shoulder-chops-with-manischewitz-glaze',
        'http://www.foodandwine.com/recipes/oysters-rocafella',
        'http://www.foodandwine.com/recipes/chicken-with-candied-cashews',
        'http://chocolateandzucchini.com/recipes/salads/oyster-mushroom-salad-with-apple-and-bergamot-recipe/',
        'http://chocolateandzucchini.com/archives/2005/03/oyster_mushroom_salad_with_apple_and_bergamot.php',
        'http://www.foodandwine.com/recipes/roast-pork-loin-with-armagnac-prune-sauce',
        'http://www.bbc.co.uk/food/recipes/panfriedporkfilletwi_88500',
        'http://seidhr.blogspot.com/2009/01/bergamot-marmalade.html',
        'http://www.davidlebovitz.com/2010/03/bergamot-marmalade-recipe/',
        'http://www.thegardenofeating.org/2008/03/meyer-lemon-and-bergamot-orange-citrus.html',
        'http://gardenofeatingblog.blogspot.com/2008/03/meyer-lemon-and-bergamot-orange-citrus.html',
        'http://www.hungrycravings.com/2010/01/single-bergamot-orange.html',
        'http://sourplum.wordpress.com/2011/01/08/bergamot-sablee-cookies/',
        'http://www.davidlebovitz.com/2007/07/planet-of-the-c-1/',
        'http://www.davidlebovitz.com/2009/06/socca-enfin/',
        'http://www.davidlebovitz.com/2009/10/crepes-dentelles/',
        'http://www.davidlebovitz.com/2010/09/plum-and-rhubarb-crisp/',
        'http://www.saveur.com/article/Recipes/Baccala-Salad',
        'http://www.saveur.com/article/Recipes/Pasta-Con-Le-Sarde-Sardines',
        'http://www.saveur.com/article/Recipes/Whole-Roasted-Branzino-with-Fennel-and-Onions',
        'http://www.saveur.com/article/Recipes/Lobster-Fra-Diavolo-Lobster-Spicy-Tomato-Sauce',
        'http://www.saveur.com/article/Recipes/Feast-of-Seven-Fishes-Shrimp-Scampi',
        'http://www.saveur.com/article/Recipes/Salt-Cod-Cake-on-Grilled-Toast',
        'http://blog.umamimart.com/2011/12/happy-hour-tom-jerry-the-original-winter-cocktail/',
        'http://umamimart.com/2011/12/happy-hour-tom-jerry-the-original-winter-cocktail/'
    ]
    label = ""
    index_name = nil
    index_table = :references
    time = Benchmark.measure do
      case ix
        when 1
          label = "Reference via URL"
          index_name = "references_index_by_url_and_type"
          urls.each { |url|
            ref = Reference.find_by url: url, type: "RecipeReference"
          }
        when 2
          label = "Reference via affiliate_id"
          index_name = "references_index_by_affil_and_type"
          Reference.where(type: "RecipeReference").map(&:affiliate_id).compact.uniq.each { |id|
            ref = Reference.find_by affiliate_id: id, type: "RecipeReference"
          }
        when 3
          label = "Reference via ID"
          index_name = "references_index_by_id"
          Reference.all[0..1000].map(&:id).each { |id|
            ref = Reference.find id
          }
        else
          return false
      end
    end
    index_status = ActiveRecord::Base.connection.index_name_exists?( index_table, index_name, false) ? "indexed" : "unindexed"
    File.open("db_timings", 'a') { |file|
      file.write(label+" (#{Time.new} #{index_status}): "+time.to_s+"\n")
    }
    true
  end

end
