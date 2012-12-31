class BmController < ApplicationController
  layout false
  
  def bookmarklet
=begin
      if params[:recipe]
          @recipe = Recipe.ensure current_user_or_guest_id, params[:recipe] # session[:user_id], params
      end
      @recipe = @recipe || Recipe.new
=end
      @recipe = Recipe.find(800)
      @area = "at_top"
      @how = "modeless"
      dialog_only = true
    end
end
