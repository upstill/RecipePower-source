# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

# We are gathered here today to seed the database with site descriptions, specifying how to 
# parse recipe pages. We will create one Site record for each site we've sussed out, but first
# we will create a default which is used for sites that don't appear in the site list.

site = Site.find_or_create_by_site('http://www.recipepower.com')
site.tags = [
    { label: :Author, path: ".hrecipe span.author" },
    { label: :Author, path: "meta[name='publisher']", attribute: :content },
    { label: :Author, path: "span[itemprop='author']" },
    { label: :Publication, path: "meta[name='publisher']", attribute: :content },
    { label: :Date,  path: "div.post div.date" } ,
    { label: :Food,  path: "#ingredients span[itemprop='ingredient'] span[itemprop='name']"},
    { label: :Food,  path: "#ingredients span[rel='v:ingredient'] span[property='v:name']"},
    { label: :Food,  path: ".recipe-tags a" },
    { label: :Food,  path: ".recipeDetails li[itemprop='ingredient'] span[itemprop='name']"},
    { label: :Food,  path: ".recipeIngred span[itemprop='ingredient'] span[itemprop='name']"},
    { label: :Food,  path: ".tdm_recipe_ingredients li[itemprop='ingredients'] span.name"},
    { label: :Food,  path: "li .ingredient .food"},
    { label: :Food,  path: "li.ingredient .name"} ,
    { label: :Food,  path: "span.recipe_structure_ingredients li[itemprop='ingredients']"},
    { label: :Food,  path: "li.ingredient a" },
    { label: :Image, path: "meta[property='og:image']", attribute: :content },
    { label: :Image, path: "#recipe-image", attribute: :href } ,
    { label: :Image, path: "div.recipe-image-large img" },
    { label: :Image, path: "img.recipe_image" }, 
    { label: :Image, path: "div.featRecipeImg img" }, 
    { label: :Image, path: "link[rel='image_source']", attribute: :href },
    { label: :Image, path: "a[rel='modal-recipe-photos'] img" } ,
    { label: :Image, path: "div.post div.entry a:first-child img:first-child" },
    { label: :Image, path: "#picture img" },
    { label: :Image, path: ".entry img" },
    { label: :Image, path: ".landscape-image img" },
    { label: :Image, path: "img[itemprop='image']", attribute: :src }, 
    { label: :Image, path: "div.box div.post div.entry a img", attribute: :src },
    { label: :Image, path: "div.photo img[itemprop='image']" }, 
    { label: :Image, path: "#photo-target" }, 
    { label: :Image, path: "img.mainIMG" }, 
    { label: :Image, path: "img.photo" },
    { label: :Image, path: "img.size-full" },
    { label: :Image, path: "img[itemprop='image']" }, 
    { label: :Ingredient,  path: "#ingredients span[itemprop='ingredient']"},
    { label: :Ingredient,  path: "#ingredients span[rel='v:ingredient']"},
    { label: :Ingredient,  path: "li[itemprop='ingredient']"},
    { label: :Ingredient,  path: "li[itemprop='ingredients']"},
    { label: :Ingredient,  path: "span[itemprop='ingredient']"},
    { label: :Ingredient,  path: "p.ingredient"},
    { label: :Ingredient,  path: "li.ingredient"},
    { label: :Publication, path: "meta[property='og:author']", attribute: :content } , 
    { label: :Tag,  path: "#recipe-filedin"} ,
    { label: :Tag,  path: "#recipe-info-attrs span.value"} ,
    { label: :Tag,  path: ".recipe-cats a"},
    { label: :Tag,  path: "#recipeCategories .categories"} ,
    { label: :Title, path: "meta[name='title']", attribute: :content }, 
    { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
    { label: :Title, path: "meta[property='og:title']", attribute: :content, cut: "Recipe: " }, 
    { label: :Title, path: "meta[property='og:title']", attribute: :content, cut: " Recipe.*$" }, 
    { label: :Title, path: "#page-title-link" }, 
    { label: :Title, path: "#recipe_title" }, 
    { label: :Title, path: "#title" },
    { label: :Title, path: ".recipe .title" },
    { label: :Title, path: ".title a" },
    { label: :Title, path: ".fn" },
    { label: :Title, path: "title" }, 
    { label: :URI, path: "meta[property='og:url']", attribute: :content } , 
    { label: :URI, path: "link[rel='canonical']", attribute: :href }, 
    { label: :URI, path: "a.permalink", attribute: :href }, 
    { label: :URI, path: "#recipe_tab", attribute: :href },
    { label: :URI, path: ".hrecipe a[rel='bookmark']", attribute: :href },
    { label: :URI, path: ".post a[rel='bookmark']", attribute: :href },
    { label: :URI, path: "input[name='uri']", attribute: :value }
]
site.save

sitekeys = {
    
    esquirefood: {
        site: "http://www.esquire.com",
        hardwire: [ :Sitename, "Esquire Food" ],
        tags: [
            { label: :Image, path: "meta[property='og:image']", attribute: "content" },
            { label: :Title, path: "meta[property='og:title']", attribute: "content", cut: "How to Make.*- " },
            { label: :URI, path: "link[rel='canonical']", attribute: "href" },
            ],
        sample: "/features/guy-food/seafood-hot-pot-recipe-0909"
    },
    esquiredrinks: {
        site: "http://www.esquire.com",
        subsite: "/drinks",
        home: "http://www.esquire.com/drinks",
        hardwire: [ :Sitename, "Esquire Drinks" ],
        tags: [
            { label: :Image, path: "#drink_infopicvid img" },
            { label: :Title, path: "meta[property='og:title']", attribute: "content", cut: " - Drink Recipe.*" },
            { label: :URI, path: "link[rel='canonical']", attribute: "href" },
            ],
            sample: "/drinks/absinthe-frappe-drink-recipe"
    },
    georgiapellegrini: {
        site: "http://georgiapellegrini.com",
        hardwire: [ :Sitename, "Georgia Pellegrini.com" ],
        tags: [
            { label: :Image, path: ".hfeed .featured-img img" },
            { label: :Ingredient, path: "li.ingredient"},
            { label: :URI, path: "link[rel='canonical']", attribute: "href" },
            { label: :Title, path: "#zlrecipe-title" },
            ],
        sample: "/2011/11/10/recipes/french-apple-tart/"
    },
    guardian: {
        site: "http://www.guardian.co.uk",
        hardwire: [ :Sitename, "Guardian UK Life and style" ],
        tags: [
            { label: :Image, path: "#main-content-picture img" },
            { label: :Image, path: "meta[property='og:image']", attribute: "content" },
            { label: :Title, path: "#article-body-blocks h2" },
            { label: :Title, path: "#main-article-info h1", cut: " recipe" },
            { label: :Title, path: "meta[property='og:title']", attribute: "content", cut: " recipe" },
            { label: :URI, path: "meta[property='og:url']", attribute: "content" }
            ],
        sample: "/lifeandstyle/2012/feb/03/grilled-broccoli-fishball-soup-recipes",
        sample: "/lifeandstyle/2012/jan/22/hugh-fearnley-whittingstall-honey-peanut-butter-bars-recipes"
    },
    nymag: {
        site: "http://nymag.com",
        hardwire: [ :Sitename, "New York Magazine" ],
        tags: [
            { label: :Title, path: "meta[property='og:title']", attribute: "content" },
            { label: :Image, path: ".listing-photo img" }
            ],
        sample: "/listings/recipe/apple-cake-with-cinnamon/"
    },
    recipegirl: {
        site: "http://www.recipegirl.com",
        hardwire: [ :Sitename, "recipe girl(tm)", :Author, "Lori Lange" ],
        tags: [
            { label: :URI, path: "link[rel='canonical']", attribute: "href" },
            { label: :Image, path: "img.size-full" },
            { label: :Title, path: "title", cut: " \\| RecipeGirl.com" }
            ],
        sample: "/2007/09/19/acorn-squash-and-chicken-chili/"
    },
    leites: {
        site: "http://leitesculinaria.com",
        hardwire: [ :Sitename, "Leite's Culinaria" ],
        tags: [
            { label: :Author, path: "span[itemprop='author']" },
            { label: :Image, path: "img[itemprop='image']", attribute: "src" },
            { label: :URI, path: "meta[property='og:url']", attribute: "content" },
            { label: :URI, path: "link[rel='canonical']", attribute: "href" },
            { label: :Ingredient, path: "li.ingredient" },
            { label: :Title, path: "meta[property='og:title']", attribute: "content" },
            ],
        sample: "/45581/recipes-pasta-puttanesca.html"
    },
    chocolateandzucchini: {
        site: "http://chocolateandzucchini.com",
        hardwire: [ :Sitename, "Chocolate & Zucchini" ],
        tags: [
          { label: :Image, path: "img.photo" },
          { label: :Title, path: ".title a" },
          { label: :URI, path: ".title a", attribute: :href }  
        ],
        sample: "/archives/2003/10/fennel_tuna_polar_bread_sandwich.php"
    },
    latartine: {
        site: "http://www.latartinegourmande.com",
        hardwire: [ :Sitename, "La Tartine Gourmande" ],
        tags: [
            { label: :Date, path: "div.post div.date" },
            { label: :Title, path: ".storytitle" },
            { label: :Image, path: ".storycontent img" },
            { label: :URI, path: "link[rel='canonical']", attribute: "href" }
            ],
        sample: "/2011/12/31/a-french-christmas-celebration/"
    },
    steamykitchen: {
        site: "http://steamykitchen.com",
        hardwire: [ :Sitename, "Steamy Kitchen" ],
        tags: [
            { label: :URI, path: "link[rel='canonical']", attribute: "href" },
            { label: :Title, path: "title", cut: " Recipe \\| Steamy Kitchen Recipes" },
            { label: :Image, path: "img.aligncenter" }
            ],
        sample: "/20575-miso-soup-recipe-tofu-mushroom.html"
    },
    cucinaitaliana: {
        site: "http://lacucinaitalianamagazine.com",
        hardwire: [ :Sitename, "La Cucina Italiana" ],
        tags: [
            { label: :URI, path: "link[rel='canonical']", attribute: "href" },
            { label: :Title, path: ".fn" },
            { label: :Image, path: "img.photo" }
            ],
        sample: "/recipe/chocolate-covered-fruit-skewers"
    },
    calabria: {
        hardwire: [ :Sitename, "Calabria from scratch" ],
        site: "https://sites.google.com/site/calabriafromscratch",
        tags: [
            { label: :Title, path: "title", cut: " - Calabria from scratch" }
            ],
        sample: "/wild-mushrooms-stuffed-with-ricotta"
    },
    food52: {
        site: "http://www.food52.com",
        hardwire: [ :Sitename, "Food 52" ],
        tags: [
            { label: :Image, path: "meta[property='og:image']", attribute: "content" },
            { label: :Title, path: "meta[property='og:title']", attribute: "content" },
            { label: :URI, path: "meta[property='og:url']", attribute: "content" }
            ],
        sample: "/recipes/9969_winter_spring_summer_fall_chicken_mousse"
    },
    oneohone: {
        site: "http://www.101cookbooks.com",
        hardwire: [ :Sitename, "101 Cookbooks"],
        hrecipe: {},
        tags: [
            { label: :Image, path: "img.photo" },
            { label: :Title, path: ".fn" }
            ],
        sample: "/archives/gougares-recipe.html"
    },
    spicyicecream: {
        site: "http://www.spicyicecream.com.au",
        hardwire: [ :Sitename, "spicy icecream"],
        tags: [
            { label: :Title, path: "title", cut: "spicy icecream: " },
            { label: :Image, path: "div.entry-content a img" },
            { label: :URI, path: "link[rel='canonical']", attribute: :href }
            ],
        sample: "/2012/02/chocolate-and-blackberry-cupcakes.html"
    },
    latimes: {
        site: "http://www.latimes.com",
        subsite: "/features/food",
        hardwire: [ :Sitename, "LA Times" ],
        tags: [
            { label: :Title, path: "meta[property='og:title']", attribute: :content, cut: "Recipe: " }, 
            { label: :Image, path: "meta[property='og:image']", attribute: :content } , 
            { label: :URI, path: "meta[property='og:url']", attribute: :content } , 
            { label: :Publication, path: "meta[property='og:author']", attribute: :content } , 
            { label: :URI, path: "link[rel='canonical']", attribute: :href },
            { label: :Image, path: "div.holder img" }
            ],
        sample: "/features/food/la-fo-0811-gravensteinrec3-20110811,0,5530279.story"
    },
    momofuku: {
        site: "http://momofukufor2.com",
        hardwire: [ :Sitename, "Momofuku for 2" ],
        tags: [
            { label: :URI, path: "link[rel='canonical']", attribute: :href },
            { label: :Image, path: "img.size-full" },
            { label: :Title, path: "h2 a[rel='bookmark']" } 
            ],
        sample: "/2010/10/pierogi-recipe/#more-5249"
    },
    kayahara: {
        site: "http://www.kayahara.ca",
        hardwire: [ :Author, "Matthew Kayahara" ],
        tags: [
            { label: :Title, path: "h1.title" },
            { label: :URI, path: "link[rel='canonical']", attribute: :href },
            { label: :Image, path: "div.box div.post div.entry a img", attribute: :src }
            ],
        sample: "/2011/11/red-velvet-carpet-microwave-sponge-cake/"
    },
    homesicktexan: {
        site: "http://homesicktexan.blogspot.co.nz",
        hardwire: [ :Author, "Jen Carlile", :Sitename, "Homesick Texan" ],
        tags: [
            { label: :Title, path: "h3.entry-title a" },
            { label: :URI, path: "link[rel='canonical']", attribute: :href },
            { label: :Image, path: ".post-body img" },
            { label: :Image, path: "link[rel='image_source']", attribute: :href }
            ],
        sample: "/2012/02/chocolate-cherry-scones-cinnamon-orange.html"
    },
    modernbeet: {
        site: "http://www.modernbeet.com",
        hardwire: [ :Author, "Jen Carlile" ],
        tags: [
            { label: :Title, path: "#maincontent .content h2 a[rel='bookmark']" },
            { label: :URI, path: "link[rel='canonical']", attribute: :href },
            { label: :Image, path: ".entry img" }
            ],
        sample: "/archives/294"
    },
    gardenandgun: {
        site: "http://gardenandgun.com",
        hardwire: [ :Sitename, "Garden&Gun" ],
        tags: [ 
            { label: :Title, path: "meta[property='dc:title']", attribute: :content },
            { label: :Image, path: ".landscape-image img" },
            { label: :Author, path: "#author-magazine", cut: "by "},
            { label: :URI, path: "link[rel='canonical']", attribute: :href }
            ], 
        sample: "/article/drunken-pie"
    },
    patis: {
        site: "http://patismexicantable.com",
        hardwire: [ :Genre, "Mexican", :Sitename, "Pati's Mexican Table" ],
        tags: [
            { label: :Title, path: ".title a" },
            { label: :Author, path: "div.hrecipe span.author" },
            { label: :URI, path: "div.hrecipe a[rel='bookmark']", attribute: :href },
            { label: :Image, path: "img.mainIMG" } 
            ],
        sample: "/2012/02/lamb-barbacoa-in-adobo.html"
    },
    jamieoliver: {
        site: "http://www.jamieoliver.com",
        passptn: "/recipes/",
        hrecipe: {},
        hardwire: [ :Sitename, "Jamie Oliver" ],
        tags: [  
            { label: :Author, path: "meta[name='publisher']", attribute: :content },
            { label: :Image, path: "img.photo" } ], 
        sample: "http://www.jamieoliver.com/recipes/salad-recipes/crab-chilli-pink-grapefruit-salad",
        sample: "http://www.jamieoliver.com/recipes/chicken-recipes/mustard-chicken-quick-dauphinoise-greens"
    },
    ideasinfood: {
        site: "http://blog.ideasinfood.com",
        hardwire: [ :Author, "Aki Kamozawa & H. Alexander Talbot", :Sitename, "Ideas in Food" ],
        tags: [  
            { label: :Title, path: "meta[property='og:title']", attribute: :content, cut: "IDEAS IN FOOD: " }, 
            { label: :URI, path: "a.permalink", attribute: :href }, 
            { label: :Image, path: "meta[property='og:image']", attribute: :content } ], 
        sample: "/ideas_in_food/2012/02/burnt-lemon-marmalade.html"
    },
    oncetv: {
        site: "http://oncetv-ipn.net/rincon/nuevo",
        hardwire: [ :Sitename, "El nuevo rincon de los sabores" ],
        tags: [  
                { label: :Image, path: "table img", attribute: :alt },
                { label: :Image,  path: "img" } ],
        sample: "/menu16_a.htm"
    },
    epicurious: { 
        site: "http://www.epicurious.com",  
        hrecipe: {},
        hardwire: [ :Sitename, "Epicurious" ],
        tags: [ 
                { label: :URI, path: "#recipe_tab", attribute: :href },
                { label: :Tag, path: "a", linkpath: "/tools/searchresults" } 
            ],
        # image: javascript var imagePath = "/images/recipesmenus/2008/2008_october/350249.jpg";
        sample: "/recipes/food/views/Grilled-Skirt-Steaks-with-Tomatillos-Two-Ways-350249",
        sample: "/recipes/food/views/Clams-with-Oregano-and-Bread-Crumbs-em-Vongole-Origanate-em-107537" },
    allrecipes: { 
        site: "http://allrecipes.com",  
        hrecipe: {},
        hardwire: [ :Sitename, "Allrecipes.com" ],
        tags: [ { label: :URI, path: "link[rel='canonical']", attribute: :href }, 
                { label: :Image,  path: "a[rel='modal-recipe-photos'] img" } ],
        sample: "/Recipe/Baked-Penne/Detail.aspx?src=rotd" },
    foodnetwork: { 
        site: "http://www.foodnetwork.com", 
        hrecipe: {},
        hardwire: [ :Sitename, "Food Network" ],
        tags: [ { label: :Food, path: "li.ingredient a"},
            { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
            { label: :URI, path: "meta[property='og:url']", attribute: :content }, 
            { label: :Image, path: "meta[property='og:image']", attribute: :content }, 
            { label: :Image, path: "a#recipe-image", attribute: :href } ],
        sample: "/recipes/mario-batali/pollo-alla-romana-roman-style-chicken-recipe/index.html"},
    seriouseats: { 
        site: "http://www.seriouseats.com", 
        hrecipe: {},
        hardwire: [ :Sitename, "Serious Eats" ],
        tags: [ { label: :Food,  path: "div.recipe-tags a" },
                # { label: :Title, path: "span.item h2.fn" },
                { label: :Image, path: "div.recipe-image-large img" },
                { label: :URI, path: "a.addthis_button_pinterest", attribute: "pi:pinit:url" } ],
        sample: "/recipes/2012/02/creamy-tom-yam-kung-thai-hot-and-sour-soup-recipe.html?ref=box_topfeatured",
        sample: "/recipes/2008/02/mario-batali-crab-tortelloni-with-scallions-recipe.html",
        },
    bestrecipes: { 
        site: "http://www.bestrecipes.com.au", 
        hrecipe: { Title: "h1.title span.fn" }, # Substitute path for title
        hardwire: [ :Sitename, "Best Recipes" ],
        tags: [
                { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
                { label: :URI, path: "link[rel='canonical']", attribute: :href }
            ],
        sample: "/recipe/Petes-Chilli-Con-Carne-L14190.html"},
        
    babbo: {
        site: "babbonyc.com",
        hardwire: [ :Sitename, "Babbo Ristorante" ],
        tags: [ { label: :Image, path: "td img", pattern: "images\/food\/" },
                { label: :Title, path: "tr td div" } ],
        sample: "http://babbonyc.com/rec-agretti.html",
        sample: "http://babbonyc.com/recipe-archive.html",
        sample: "http://babbonyc.com/rec-carpaccio_zucchini.html"
    },
    batali: {
        site: "mariobatali.com",
        hardwire: [ :Sitename, "Mario Batali" ],
        tags: [ { label: :Tltle, path: "li.restaurantscontenttitle" }],
        sample: "http://www.mariobatali.com/recipes_aracine.cfm",
        sample: "http://www.mariobatali.com/food_wine_recipes.cfm"
    },
    martha: { 
        site: "http://www.marthastewart.com", 
        hrecipe: {},
        hardwire: [ :Sitename, "marthastewart.com" ],
        tags: [ 
                { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
                { label: :URI, path: "meta[property='og:url']", attribute: :content }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content }, 
                { label: :Image, path: "img.photo" },
                { label: :URI, path: "link[rel='canonical']", attribute: :href }
                ],
        sample: "/336715/shrimp-tomato-and-basil-pasta?center=344318&gallery=341264&slide=281119"
    },
    cooksillustrated: {
        site: "http://www.cooksillustrated.com",
        sample: "/recipes/detail.asp?docid=14939",
        hardwire: [ :Sitename, "Cook's Illustrated"],
        ttlcut: "- Cooks Illustrated", 
        tags: [
            { label: :Image, path: "img[itemprop='photo']" }
            ]
    },
    cooks: { 
        site: "http://www.cooks.com", 
        hrecipe: {},
        breadcrumbs: "div#breadcrumb a",
        hardwire: [ :Sitename, "Cooks.com" ],
        tags: [ 
            { label: :Title, path: "span.fn" },
            { label: :Image, path: "img.photo" } ],
        sample: "/rec/view/0,1657,140186-240197,00.html" },
    splendid: { 
        site: "http://www.publicradio.org", 
        home: "http://splendidtable.publicradio.org", 
        hrecipe: {},
        hardwire: [ :Sitename, "The Splendid Table" ],
        tags: [ { label: :Tag,  path: "div#recipeCategories .categories"} ],
        sample: "/columns/splendid-table/recipes/green_beans_with_lemon_garlic_and_parmigiano_gremolata.html", 
        subsite: "" },
    food: { 
        site: "http://www.food.com", 
        hrecipe: {},
        hardwire: [ :Sitename, "Food.com" ],
        tags: [ { label: :Tag,  path: ".recipe-cats a"},
                { label: :Image, path: "img[itemprop='image']" }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content }, 
                { label: :URI, path: "link[rel='canonical']", attribute: :href }, 
                { label: :Tag,  path: "#recipe-filedin"} ],
        sample: "http://low-cholesterol.food.com/recipe/steak-spinach-sesame-salad-468298"},
    delish: { 
        site: "http://www.delish.com", 
        hardwire: [ :Sitename, "Delish" ],
        tags: [ { label: :Ingredient,  path: "li.ingredient"},
                { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
                { label: :URI, path: "link[rel='canonical']", attribute: :href }, 
                { label: :URI, path: "meta[property='og:url']", attribute: :content }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content }, 
                { label: :Image, path: "img#photo-target" }, 
                { label: :Food,  path: "li.ingredient span.name"} ],
        sample: "/recipefinder/roasted-pumpkin-soup-mushrooms-chives"},
    realsimple: { 
        site: "http://www.realsimple.com", 
        hardwire: [ :Sitename, "Real Simple" ],
        tags: [ { label: :Food,  path: "div.recipeIngred span[itemprop='ingredient'] span[itemprop='name']"},
                { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
                { label: :URI, path: "meta[property='og:url']", attribute: :content }, 
                { label: :URI, path: "link[rel='canonical']", attribute: :href }, 
                { label: :Image, path: "div.featRecipeImg img" }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content }, 
                { label: :Ingredient,  path: "div.recipeIngred span[itemprop='ingredient']"} ],
        sample: "/food-recipes/browse-all-recipes/fish-tacos-cucumber-relish-00000000057124/"},
    myrecipes: { 
        site: "http://www.myrecipes.com", 
        hardwire: [ :Sitename, "MyRecipes" ],
        tags: [ { label: :Food,  path: "div.recipeDetails li[itemprop='ingredient'] span[itemprop='name']"},
                { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
                { label: :URI, path: "meta[property='og:url']", attribute: :content }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content }, 
                { label: :Ingredient,  path: "div.recipeDetails li[itemprop='ingredient']"} ],
        sample: "/recipe/apple-sesame-chicken-10000001732652/"},
    cookstr: { 
        site: "http://www.cookstr.com", 
        hardwire: [ :Sitename, "cookstr" ],
        tags: [ { label: :Food,  path: "span.recipe_structure_ingredients li[itemprop='ingredients'] span"},
                { label: :Ingredient,  path: "span.recipe_structure_ingredients li[itemprop='ingredients']"},
                { label: :Title, path: "#recipe_title" }, 
                { label: :Image, path: "div.photo img[itemprop='image']" }, 
                { label: :Tag,  path: "#recipe-info-attrs span.value"} ],
        sample: "/recipes/coq-au-riesling"},
    chow: { 
        site: "http://www.chow.com", 
        hardwire: [ :Sitename, "CHOW" ],
        tags: [ { label: :Food,  path: "div#ingredients span[itemprop='ingredient'] span[itemprop='name']"},
                { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
                { label: :URI, path: "meta[property='og:url']", attribute: :content }, 
                { label: :Image, path: "img.recipe_image" }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content }, 
                { label: :Ingredient,  path: "div#ingredients span[itemprop='ingredient']"} ],
        sample: "/recipes/30282-chicken-and-smoked-andouille-jambalaya"},
    kraft: { 
        site: "http://www.kraftrecipes.com", 
        hardwire: [ :Sitename, "Kraft Recipes" ],
        tags: [ { label: :Food,  path: "div#ingredients span[rel='v:ingredient'] span[property='v:name']"},
                { label: :Title, path: "meta[name='title']", attribute: :content }, 
                { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
                { label: :URI, path: "link[rel='canonical']", attribute: :href }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content }, 
                { label: :Ingredient,  path: "div#ingredients span[rel='v:ingredient']"} ],
        sample: "/recipes/one-pot-taco-pasta-127214.aspx" },
    bbc: { 
        site: "http://www.bbc.co.uk", 
        hrecipe: { },
        hardwire: [ :Sitename, "BBC Food" ],
        tags: [ { label: :Food,  path: "li p.ingredient a.food"},
                { label: :URI, path: "input[name='uri']", attribute: :value },
                { label: :Ingredient,  path: "li p.ingredient"} ],
        sample: "/food/recipes/filletsofsolewrapped_90825",
        sample: "/food/recipes/hotchickencakeswithh_92226" },
    thedailymeal: { 
        site: "http://www.thedailymeal.com", 
        hardwire: [ :Sitename, "The Daily Meal" ],
        tags: [ { label: :Food,  path: "div.tdm_recipe_ingredients li[itemprop='ingredients'] span.name"},
                { label: :URI, path: "link[rel='canonical']", attribute: :href }, 
                { label: :Title, path: "#page-title-link" }, 
                { label: :Title, path: "title" }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content }, 
                { label: :Image, path: ".tdm_recipe_image img[itemprop='image']", attribute: :src }, 
                { label: :Ingredient,  path: "div.tdm_recipe_ingredients li[itemprop='ingredients']"} ],
        sample: "/rotisserie-lamb-mint-rosemary-and-garlic-recipe"},
    smitten: {
        site: "http://smittenkitchen.com",
        hardwire: [ :Sitename, "smitten kitchen" ],
        tags: [ 
                { label: :URI, path: "link[rel='canonical']", attribute: :href }, 
                { label: :URI, path: "div.post h2 a[rel='bookmark']", attribute: :href },
                { label: :Title, path: "div.post h2 a[rel='bookmark']" },
                { label: :Image,  path: "div.post div.entry a:first-child img:first-child" },
                # { label: :Ingredients,  path: "div.post div.entry p br" },
                { label: :Date,  path: "div.post div.date" } ],
        sample: "http://smittenkitchen.com/2012/02/cheddar-beer-and-mustard-pull-apart-bread/"
    },
    pepin: { # Wordpress
        site: "http://blogs.kqed.org/essentialpepin",
        # subsite: "http://blogs.kqed.org/essentialpepin",
        breadcrumbs: "p#breadcrumbs a",
        hardwire: [ :Sitename, "Essential Pepin" ],
        tags: [ 
                { label: :URI, path: "link[rel='canonical']", attribute: :href },
                { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
                { label: :URI, path: "meta[property='og:url']", attribute: :content }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content } 
            ],
        # sample: "/2011/09/23/green-couscous/",
        sample: "http://blogs.kqed.org/essentialpepin/categories/recipes",
        sample: "http://blogs.kqed.org/essentialpepin/2011/09/19/brandade-de-morue-au-gratin/"
    },
    hertzmann: {
        site: "www.hertzmann.com",
        hardwire: [ :Sitename, "Peter Hertzmann" ],
        tags: [
                { label: :Title, path: "#title" },
                { label: :Image, path: "#picture img" },
                { label: :Title, path: ".recipe .title" },
                { label: :Ingredient, path: ".recipe .ingredient_right" }
            ],
        sample: "http://www.hertzmann.com/articles/2008/poach/",
        sample: "http://www.hertzmann.com/articles/2005/pot-au-feu/recipe.php",
        sample: "http://www.hertzmann.com/articles/2005/pot-au-feu"
    },
    cookingchannel: {
        site: "http://www.cookingchanneltv.com/recipes",
        hrecipe: {},
        hardwire: [ :Sitename, "Cooking Channel" ],
        tags: [ 
            { label: :Image, path: "#rec-photo img" },
            { label: :Author, path: ".rByline", cut: "Recipe Courtesy of " } 
            ],
        sample: "/mario-batali/quail-spiedini-with-sage-polenta-and-asiago-recipe/index.html"
    },
    mariotoday: {
        site: "http://today.msnbc.msn.com",
        home: "http://today.msnbc.msn.com/id/3041421/ns/today-foodwine/",
        hrecipe: {},
        hardwire: [ :Sitename, "Today FOOD" ],
        tags: [ 
                { label: :URI, path: "link[rel='canonical']", attribute: :href },
                { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
                { label: :URI, path: "meta[property='og:url']", attribute: :content }, 
                { label: :Image, path: "meta[property='og:image']", attribute: :content },
                { label: :Author, path: "span.chefname[itemprop='author']" }
            ],
        sample: "http://today.msnbc.msn.com/id/43045427/ns/today-food/t/make-mario-batalis-fettuccine-alfredo-less-minute/"
    },
    foodandwine: {
        site: "www.foodandwine.com",
        passptn: "\/recipes\/",
        hardwire: [ :Sitename, "Food & Wine" ],
        tags: [
            { label: :Title, path: "meta[property='og:title']", attribute: :content }, 
            { label: :URI, path: "meta[property='og:url']", attribute: :content }, 
            { label: :Image, path: "meta[property='og:image']", attribute: :content },
            { label: :Author, path: "span[itemprop='author']" }
            ],
            sample: "http://www.foodandwine.com/chefs"
    },
    "foodandwine-gloss".to_sym => { 
        site: "www.foodandwine.com",
        gloss: [ { label: :Author, path: "a", linkpath: "\/chefs\/" }
        ],
        sample: "http://www.foodandwine.com/recipes/chicken-with-piquillos"
    },
    "food-dictionary".to_sym => { 
        site: "http://www.food.com", 
        sample: "/library/achar-356" },
    "realsimple-food".to_sym => {
        site: "http://www.realsimple.com", 
        gloss: [ { label: :Food,  path: 'div.txt_content h2 a'} ],
        subsite: "/food-recipes/ingredients-guide",
        sample: "/food-recipes/ingredients-guide/category-a/index.html" },
    "foodista-food".to_sym => { 
        site: "http://www.foodista.com", 
        gloss: [ { label: :Food,  path: 'div#main-wrapper div.content div.view-content span.field-content a'} ],
        sample: "/browse/foods", 
        subsite: "/browse/foods"},
    "cookthink-tool".to_sym => { 
        site: "http://www.cookthink.com", 
        gloss: [ { label: :Tool,  path: 'div.inner li a'} ],
        sample: "/reference/browse?tag=Tool"},
    "cookthink-process".to_sym => { 
        site: "http://www.cookthink.com", 
        gloss: [ { label: :Process,  path: 'div.inner li a'} ],
        sample: "/reference/browse?tag=Technique" },
    "cookthink-food".to_sym => { 
        site: "http://www.cookthink.com", 
        gloss: [ { label: :Food,  path: 'div.inner li a'} ],
        sample: "/reference/browse?tag=Ingredient"},
    "cookthink-genre".to_sym => { 
        site: "http://www.cookthink.com", 
        gloss: [ { label: :Genre,  path: 'div.inner li a'} ],
        sample: "/reference/browse?tag=Cuisine"},
    "bbc-food".to_sym => { 
        site: "http://www.bbc.co.uk", 
        gloss: [ { label: :Food,  path: 'ol.foods li.food a' } ],
        sample: "/food/ingredients/by/letter/a", 
        subsite: "/food/ingredients" }
    # foodterms: { XXX Redundant (based on Food-Lover's Companion also) 
        # tags: [ { label: :Food,  path: "ul.idxlist" } ],
        # site: "http://www.foodterms.com", 
        # sample: "/encyclopedia/a/index.html" }
    # Not compliant: smittenkitchen: "http://smittenkitchen.com/2012/02/cheddar-beer-and-mustard-pull-apart-bread/"
    # Not compliant: foodista: "http://www.foodista.com",
    # Not compliant: food52: "http://www.food52.com",
    # Not compliant: recipeswiki: "http://recipes.wikia.com",
    # Not compliant: theworldrecipebook: "http://www.theworldrecipebook.com",
    # Not compliant: tgcmagazine: "http://www.tgcmagazine.com",
    # Not compliant: gilttaste: "http://www.gilttaste.com",
}

sitekeys.keys.each { |handle|
    rcd = sitekeys[handle]
    if rcd[:tags] # Not handling glossary records
        siteuri = rcd[:site]
        # The site spec might not include a scheme
        siteuri = "http://#{siteuri}" unless siteuri =~ /^\w*:/
        
        # Either find a matching Site record or create a new one
        sampleuri = rcd[:sample]
        # The sample may just be a path, without the site
        sampleuri = siteuri+sampleuri if sampleuri =~ /^\//
        if site = Site.by_link(sampleuri) 
            subsite = rcd[:subsite]
            if (subsite && (site.subsite.nil? || (subsite != site.subsite)))
                # The site doesn't include the subsite => make new record
                site = Site.create :sample=>sampleuri, :subsite => subsite
            end
            site.tags = rcd[:tags]
            site.home = rcd[:home] if rcd[:home] # If home is different from site
            ix = 0
            if hw = rcd[:hardwire]
                while ix < hw.size
                    if hw[ix] == :Sitename
                        site.name = hw[ix+1]
                    end
                    ix = ix + 2
                end
            end
            site.save
        end
    end
}

# Seed logins--unless they're already there
unless User.by_name :guest
    User.new( username: "maxgarrone@gmail.com", 
            email: "maxgarrone@gmail.com", 
            password_hash: "$2a$10$jDwmhYV1GCWTlh2PfogRFu1b9ztDD04ngi/WUnYvxSBJ1ohML/S8G", 
            password_salt: "$2a$10$jDwmhYV1GCWTlh2PfogRFu").save validate: false
    User.new(username: "aaron", 
            email: "sweetaz@gmail.com",
            password_hash: "$2a$10$2QSRHaYD8EB89FT42HF8X.3hSLB/xuAB.ryH2ucMikUGbldDgqr46",
            password_salt: "$2a$10$2QSRHaYD8EB89FT42HF8X.").save validate: false
    User.new(username: "upstill", 
            email: "steve@upstill.net", 
            password_hash: "$2a$10$SlXpc.5frJuxeUA0O/t46eRgrWbBqb9D4cKIoOHM44QJnA2bVthFW", 
            password_salt: "$2a$10$SlXpc.5frJuxeUA0O/t46e").save validate: false
	User.new(username: :super, 
	        email: "webmaster@recipepower.com",
            password_hash: "$2a$10$KiEDQDXW52BXJJsDAPEV7eJtk54EDHQSAlqmDa/qkzkeJXCPv0FMS", 
            password_salt: "$2a$10$KiEDQDXW52BXJJsDAPEV7e").save validate: false
    User.new(username: :guest).save validate: false
end

max = User.find(1)
Tag.all.each { |t| t.users << max unless t.users.exists?(:id=>1)}

Expression.all.each { |exp| exp.destroy }
Tag.all.each { |tag| tag.tagtype = 0 ; tag.save }
Referent.all.each { |rr| rr.destroy }
ReferentRelation.all.each { |rr| rr.destroy }

Referent.express "Dairy", :Food
Referent.express "Meat", :Food
Referent.express "Pork", :Food
Referent.express "Beef", :Food
Referent.express "Lamb", :Food
Referent.express "Poultry", :Food
Referent.express "Game", :Food
Referent.express "Fish", :Food
Referent.express "Vegetable", :Food
Referent.express "Grain", :Food
Referent.express "Fats & Oils", :Food
Referent.express "Seasonings", :Food

Referent.express "Holidays", :Occasion
Referent.express "Events", :Occasion
Referent.express "Super Bowl", :Occasion
Referent.express "Barbecue", :Occasion

Referent.express "Asian", :Genre
Referent.express "Latin American", :Genre
Referent.express "South American", :Genre
Referent.express "Caribbean", :Genre
Referent.express "European", :Genre
Referent.express "African", :Genre
Referent.express "Pacific", :Genre
Referent.express "US", :Genre
Referent.express "Canadian", :Genre
Referent.express "Middle Eastern", :Genre

Referent.express "Beverage", :Role
Referent.express "Soup", :Role
Referent.express "First Course", :Role
Referent.express "Entree", :Role
Referent.express "Dessert", :Role

Referent.express "Blogger", :Author
Referent.express "Chef", :Author

Referent.express "Book", :Source
Referent.express "Magazine", :Source
Referent.express "Online", :Source

Referent.express "Cutting", :Process
Referent.express "Baking", :Process
Referent.express "Mixing", :Process
Referent.express "Stovetop", :Process

Referent.express "Volume--English", :Unit
Referent.express "Volume--Metric", :Unit
Referent.express "Weight--English", :Unit
Referent.express "Weight--Metric", :Unit
Referent.express "Temperature", :Unit
Referent.express "Time", :Unit

Referent.express "Dairy", :StoreSection
Referent.express "Produce", :StoreSection
Referent.express "Meat", :StoreSection
Referent.express "Frozen Foods", :StoreSection
Referent.express "Juices", :StoreSection
Referent.express "Beer & Wine", :StoreSection
Referent.express "Baking Supplies", :StoreSection
Referent.express "Canned Vegetables", :StoreSection
Referent.express "Canned Fruit", :StoreSection

Referent.express "Closet", :PantrySection
Referent.express "Drawers", :PantrySection
Referent.express "Spices", :PantrySection
Referent.express "Fridge", :PantrySection
Referent.express "Freezer", :PantrySection

Referent.express "Cutting", :Tool
Referent.express "Mixing", :Tool
Referent.express "Stovetop", :Tool
Referent.express "Baking", :Tool
Referent.express "Other Tools", :Tool

Referent.express "Diets", :Interest
Referent.express "Genres", :Interest

# LinkRef.import_file "db/data/FoodLover"
Expression.all.each { |exp| exp.destroy }
Tag.all.each { |tag| tag.tagtype = 0 ; tag.save }
Referent.all.each { |rr| rr.destroy }
ReferentRelation.all.each { |rr| rr.destroy }

LinkRef.import_CSVfile "db/data/Full Dictionary Revised.csv"
