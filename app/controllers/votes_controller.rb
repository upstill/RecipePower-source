class VotesController < ApplicationController
  before_action :set_vote, only: [:show, :edit, :update, :destroy, :create]

  helper_method :vote_button_replacement

  # GET /votes
  def index
    @votes = Vote.all
  end

  # GET /votes/1
  def show
  end

  # GET /votes/new
  def new
    @vote = Vote.new
  end

  # GET /votes/1/edit
  def edit
  end

  # POST /votes
  def create
    # Get from first_or_initialize implicitly # @vote = Vote.new(vote_params)
    if @vote.up != (up = params[:up] == 'true')
      @vote.up = up
      @vote.save
      flash.now[:notice] = "Your vote has been counted."
    else
      flash.now[:notice] = %Q{You've voted this #{up ? "up" : "down"} before.}
    end
    respond_to do |format|
      format.js do
        button = with_format("html") { render_to_string partial: "button", locals: { entity: @vote.entity, style: params[:style] || "h" } }
        @jsondata = # with_format("json") { render "show", layout: false }
          { replacements: [
               [ "div#"+view_context.vote_div_id(@vote.entity), button ]
            ],
            notice: flash[:notice]
          }
        render template: "shared/get_content"
      end
    end
  end

  # PATCH/PUT /votes/1
  def update
    if @vote.update(vote_params)
      redirect_to @vote, notice: 'Vote was successfully updated.'
    else
      render action: 'edit'
    end
  end

  # DELETE /votes/1
  def destroy
    @vote.destroy
    redirect_to votes_url, notice: 'Vote was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_vote
      elmts = request.path.split('/')
      entity_type, entity_id = elmts[-2], elmts[-1]
      @vote = Vote.where(
          entity_type: entity_type.singularize.capitalize,
          entity_id: entity_id,
          user_id: current_user.id
      ).first_or_initialize
    end

    # Only allow a trusted parameter "white list" through.
    def vote_params
      params.require(:vote).permit(:user_id, :entity_type, :entity_id, :up)
    end
end
