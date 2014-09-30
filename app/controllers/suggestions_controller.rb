class SuggestionsController < ApplicationController
  before_action :set_suggestion, only: [:show, :edit, :update, :destroy]

  # GET /suggestions
  def index
    @suggestions = Suggestion.all
  end

  # GET /suggestions/1
  def show
  end

  # GET /suggestions/new
  def new
    @suggestion = Suggestion.new
  end

  # GET /suggestions/1/edit
  def edit
  end

  # POST /suggestions
  def create
    @suggestion = Suggestion.new(suggestion_params)

    if @suggestion.save
      redirect_to @suggestion, notice: 'Suggestion was successfully created.'
    else
      render action: 'new'
    end
  end

  # PATCH/PUT /suggestions/1
  def update
    if @suggestion.update(suggestion_params)
      redirect_to @suggestion, notice: 'Suggestion was successfully updated.'
    else
      render action: 'edit'
    end
  end

  # DELETE /suggestions/1
  def destroy
    @suggestion.destroy
    redirect_to suggestions_url, notice: 'Suggestion was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_suggestion
      @suggestion = Suggestion.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def suggestion_params
      params.require(:suggestion).permit(:base_type, :base_id, :viewer, :session, :filter, :rc, :results)
    end
end
