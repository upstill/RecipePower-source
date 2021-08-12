require 'image_reference.rb'

class RecipeServices
  attr_accessor :recipe 
  
  def initialize(recipe, current_user=nil)
    @recipe = recipe
    # @current_user = current_user
  end

  def show_tags(file=STDOUT)
    file.puts tags.sort { |t1, t2| t1.id <=> t2.id }.collect { |tag| "#{tag.id.to_s}: #{tag.name}" }.join "\n"
  end

end
