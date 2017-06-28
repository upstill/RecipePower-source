class RecipesController < CollectibleController

  before_filter :login_required, :except => [:index, :show, :associated, :capture, :collect ]
  before_filter { @focus_selector = '#recipe_url' }
    
  filter_access_to :all
  # include ApplicationHelper
  # include ActionView::Helpers::TextHelper

  def capture
    super
  end

  def index
    redirect_to default_next_path
    # return if need_login true
    # Get the collected recipes for the user named in query
  end

  def revise # modify current recipe to reflect a client-side change
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = current_user_or_guest_id # session[:user_id]
	# Modification instructions are in query strings:
	# :do => 'add', 'remove'
	# :what => "Genre", "Technique", "Course"
	# :name => string identifier (name of element)
    if(params[:do] == 'remove')
    	c = @recipe.tags
    	c.each { |g| c.delete(g) if g.name == params[:name] }
    elsif(params[:do] == 'add')
    	if(params[:what] == 'Tags')
    	end
    end
    render :text => params[:name]
    return true
  end

  # parse a recipe fragment, tagging it with the named class and (possibly)
  #  looking for substrings to match
  def parse
      # In general the text is free of HTML formatting, except that 1) presumably
      # spans denoting microformat data are preserved, and 2) prior
      # calls to parse sections may have left spans behind
      words = params[:html]
      result = Recipe.parse words, params[:class]

      # For now, just return the text as sent
      render :text => result
  end
end
