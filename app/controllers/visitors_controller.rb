class VisitorsController < ApplicationController
  def new
	@title = "Sign up"
	@visitor = Visitor.new
  end
  def show
	@visitor = Visitor.find(params[:id])
  end
  def create
    @visitor = Visitor.new(params[:visitor])
    # Don't even try to save unless there's content in the strings
    if(((@visitor.baremail.nil? || @visitor.baremail.empty?) && 
	(@visitor.question.nil? || @visitor.question.empty?)) || 
    	@visitor.save)
      # Handle a successful save by redirecting to survey.
      redirect_to "http://www.surveymonkey.com/s/T2GZSC5"
      # flash[:success] = "Welcome to RecipePower!"
      # redirect_to (visitor_path (@visitor))
    else
      @title = "Sign up"
      render 'new'
    end
  end

end
