class RecipeServices
  attr_accessor :current_user, :recipe
  
  def initialize(recipe, current_user=nil)
    @recipe = recipe
  end
  
  # Migrate x_tags to tags
  def self.supplant_x_tags
    Recipe.all.each do |recipe|
      xtags = recipe.x_tags
      recipe.users.each do |user|
        recipe.current_user = user.id
        recipe.tags = xtags
        recipe.save
      end
  end
  
  def show_x_tags
    puts @recipe.x_tags.collect { |tag| "#{tag.id.to_s}: #{tag.name}" }.join "\n"
  end
  
end