require 'reference.rb'

class RecipeServices
  attr_accessor :current_user, :recipe
  
  def initialize(recipe, current_user=nil)
    @recipe = recipe
    @current_user = current_user
  end

  # Find all recipes that are redundant (ie., they have the same canonical url as another) and merge them into the one that already owns the URL.
  def self.fix_redundant
    redundant = []
    current_ids = Set.new Reference.where(type: "RecipeReference").map(&:affiliate_id)
    all_ids = Set.new Recipe.all.map(&:id)
    (all_ids - current_ids).each { |id|
      rcp = Recipe.find id
      old_ref = RecipeReference.by_link(rcp.url) # Get the competitor
      old_rcp = old_ref.recipe
      puts "Recipe ##{rcp.id} (url #{rcp.url})..."
      puts "  ...clashes with recipe ##{old_rcp.id} (url #{old_rcp.url})"
      self.new(rcp).merge_into old_rcp
      self.new(old_rcp).test_conversion
      x=2
    }
  end

  # Merge this recipe into another, optionally deleting it
  def merge_into rcp, destroy=false
    # This recipe may be presenting a URL that redirects to the target => include that URL in the table
    obj = RecipeReference.find_or_initialize @recipe.url, affiliate: rcp
    # Apply thumbnail and comment, if any
    unless @recipe.picurl.blank? || !rcp.picurl.blank?
      rcp.picurl = @recipe.picurl
    end
    rcp.description = @recipe.description if rcp.description.blank?
    unless @recipe.rcprefs.empty?
      xfers = []
      @recipe.rcprefs.each { |my_ref|
        # Redirect each rcpref to the other, merging them when there's already one for a user
        # comment, private, status, in_collection, edit_count
        if other_ref = rcp.rcprefs.where(user_id: my_ref.user_id).first
          # Transfer reference information
          other_ref.private ||= my_ref.private
          other_ref.comment = my_ref.comment if other_ref.comment.blank?
          other_ref.in_collection ||= my_ref.in_collection
          other_ref.edit_count += my_ref.edit_count
          other_ref.save
        else
          # Simply redirect the ref, thus moving the owner from the old recipe to the new
          # (Need to do this after iterating over the recipe's refs)
          xfers << my_ref.clone
        end
      }
      unless xfers.empty?
        rcp.rcprefs = rcp.rcprefs + xfers
      end
    end
    # Move taggings from the old recipe to the new
    xfers =
    @recipe.taggings.collect { |tagging|
      tagging.clone unless rcp.taggings.exists?(tagging.attributes.slice :user_id, :tag_id)
    }.compact
    unless xfers.empty?
      rcp.taggings = rcp.taggings + xfers
    end
    # Move feed_entries from the old recipe to the new
    FeedEntry.where(:recipe_id => @recipe.id).each { |fe|
      fe.recipe = rcp
      fe.save
    }
    @recipe.save
    rcp.save
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
          rcpids = user.recipe_ids
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
