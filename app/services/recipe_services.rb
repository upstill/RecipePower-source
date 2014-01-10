class RecipeServices
  attr_accessor :current_user, :recipe
  
  def initialize(recipe, current_user=nil)
    @recipe = recipe
    @current_user = current_user
  end

  def scrape
    extractions = SiteServices.extract_from_page(@recipe.url )
    puts "Recipe # #{@recipe.id}: #{@recipe.title}"
    puts "\tsite: #{@recipe.site.name} (#{@recipe.site.home_page})"
    puts "\turl: #{@recipe.url}"
    puts "\thref: #{@recipe.href}"
    puts "\tdescription: #{@recipe.description}"
    puts "\tpicurl: #{@recipe.picurl}"
    puts "\tExtractions:"
    extractions.each { |k, v| puts "\t\t#{k.to_s}: #{v}"}
  end

  def robotags= extractions={}
    ts = nil
    if author = extractions["Author Name"]
      ts ||= TaggingServices.new @recipe
      ts.tag_with author, tagger: User.super_id, type: "Author"
    end
    if tagstring = extractions["Tags"]
      ts ||= TaggingServices.new @recipe
      tagstring.split(',').collect { |tagname| tagname.strip!; tagname if (tagname.length>0) }.compact.each { |tagname|
        ts.tag_with tagname, tagger: User.super_id
      }
    end
  end

  # The robotags are those owned by super
  def robotags
    @recipe.tags User.super_id
  end

=begin
  def supplant_x_tags
    @recipe.current_user = @current_user
    self.tags = @recipe.x_tags
    @recipe.save
  end
  
  # Migrate x_tags to tags
  def self.supplant_x_tags
    Tagging.all.each { |tg| tg.destroy }
    Recipe.all.each do |recipe|
      xtags = recipe.x_tags
      recipe.users.each do |user|
        rs = self.new recipe, user.id
        rs.supplant_x_tags
      end
    end
  end
  
  def show_x_tags(file=STDOUT)
    file.puts @recipe.x_tags.sort { |t1, t2| t1.id <=> t2.id }.collect { |tag| "#{tag.id.to_s}: #{tag.name}" }.join "\n"
  end
  
  def compare_tags(file=STDOUT, xfile=STDOUT)
    file.puts "-------- Recipe ##{recipe.id.to_s}: '#{recipe.title}' for user ##{current_user.to_s} ------------"
    xfile.puts "-------- Recipe ##{recipe.id.to_s}: '#{recipe.title}' for user ##{current_user.to_s} ------------"
    show_tags file
    show_x_tags xfile
  end
  
  def self.sample_tags (n=5)
    File.open("/tmp/sample_x_tags", 'w') do |xfile| 
      File.open("/tmp/sample_tags", 'w') do |file| 
        users = User.all
        xfile.puts ">>>>>>>>>>>>>>>>>> Comparing random user/recipe combos: "
        file.puts ">>>>>>>>>>>>>>>>>> Comparing random user/recipe combos: "
        count = n
        while (count >= 0)
          # Pick a random user and a random recipe that they own
          user = users[rand(users.count)]
          rcpids = user.recipes
          next unless rcpids.count > 0
          rcpid = rcpids[rand(rcpids.count)]
          # Compare the x_tags with the user's tags
          if recipe = Recipe.where(:id => rcpid).first
            rs = self.new recipe, user.id
            rs.compare_tags file, xfile
          end
          count = count-1
        end
        xfile.puts ">>>>>>>>>>>>>>>>>> Comparing all ownerships: "
        file.puts ">>>>>>>>>>>>>>>>>> Comparing all ownerships: "
        rcprefs = Rcpref.all.each do |rr|
          if recipe = Recipe.where(:id => rr.recipe_id).first
            rs = self.new recipe, rr.user_id
            rs.compare_tags file, xfile
          end
        end
      end
    end
  end
=end
  
  def tags
    @recipe.tags(@current_user)
  end
  
  def tags=(tags)
    @recipe.current_user = @current_user
    @recipe.tags = tags
  end
  
  def show_tags(file=STDOUT)
    file.puts tags.sort { |t1, t2| t1.id <=> t2.id }.collect { |tag| "#{tag.id.to_s}: #{tag.name}" }.join "\n"
  end
end
