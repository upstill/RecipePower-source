class VotesController < ApplicationController
  before_action :set_vote, only: [:show, :edit, :update, :destroy, :create]

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

  # POST /votes/<entity_type>/<entity_id>
  def create
    if current_user
      @vote.up = params[:up] == 'true'
      update_and_decorate @vote.entity
      if @vote.up_changed?
        @vote.save
        flash[:popup] = "Your vote has been counted."
      else
        flash[:popup] = %Q{You've already voted this #{@vote.up ? "up" : "down"}.}
      end
    else
      flash[:alert] = "Sorry, but you need to be logged in to vote on anything."
      render :errors
    end
  end

  # PATCH/PUT /votes/<entity_type>/<entity_id>
  def update
    if @vote.update_attribute :up, (params[:up] == 'true')
      redirect_to @vote, notice: 'Vote was successfully updated.'
    else
      render action: 'edit'
    end
  end

  # DELETE /votes/<entity_type>/<entity_id>
  def destroy
    @vote.destroy if @vote.persisted? # Don't bother if it's only initialized
    redirect_to votes_url, notice: 'Vote was successfully destroyed.'
  end

  private
    # Ensure the vote exists.
    def set_vote
      @vote = Vote.find_or_initialize_by(
          entity_type: params[:entity].camelize,
          entity_id: params[:id],
          user_id: current_user.id
      )
    end

    # Only allow a trusted parameter "white list" through.
    def vote_params
      params.require(:vote).permit :up
    end
end
