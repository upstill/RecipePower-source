class AnswersController < ApplicationController
  before_action :set_answer, only: [:show, :edit, :update, :destroy]

  # GET /answers
  def index
    @answers = Answer.all
  end

  # GET /answers/1
  def show
  end

  # GET /answers/new
  def new
    @answer = Answer.new
  end

  # GET /answers/1/edit
  def edit
  end

  # POST /answers
  def create
    ts = Answer.find_or_create_by params[:answer].slice(:user_id, :question_id)
    ts.update_attributes params[:answer]
    ts.save
    update_and_decorate ts
    if update_and_decorate
      flash[:popup] = 'Answer duly noted.'
    else
      render :new
    end
  end

  # PATCH/PUT /answers/1
  def update
    if update_and_decorate
      flash[:popup] = 'Answer duly noted.'
      render :create
    else
      render :edit
    end
  end

  # DELETE /answers/1
  def destroy
    @answer.destroy
    redirect_to answers_url, notice: 'Answer was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_answer
      @answer = Answer.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def answer_params
      params.require(:answer).permit(:answer, :user_id, :question_id)
    end
end
