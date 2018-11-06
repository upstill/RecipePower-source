=begin
An Expression links a Referent to a Tag. It declares that a semantic entity
(a Referent) can be referred to by a particular lexical entity (a Tag).
Fields:
    -- tag_id, referent_id: the items being linked
    -- form: perhaps a tag for a specific grammatical variant (e.g. plural, feminine)
        for a given locale
    -- locale: the language in which this expression is valid
=end
class ExpressionsController < ApplicationController
  before_action :set_expression, only: [:show, :edit, :update, :destroy]
  # GET /expressions
  # GET /expressions.json
  def index
    @expressions = Expression.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @expressions }
    end
  end

  # GET /expressions/1
  # GET /expressions/1.json
  def show
    smartrender
  end

  # GET /expressions/new
  # GET /expressions/new.json
  def new
    @expression = Expression.new
    smartrender
  end

  # GET /expressions/1/edit
  def edit
    smartrender
  end

  # POST /expressions
  # POST /expressions.json
  def create
    @expression = Expression.new expression_params
    respond_to do |format|
      if @expression.save
        format.html { redirect_to @expression, notice: 'Expression was successfully created.' }
        format.json { render json: @expression, status: :created, location: @expression }
      else
        format.html { render action: "new" }
        format.json { render json: @expression.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /expressions/1
  # PUT /expressions/1.json
  def update
    respond_to do |format|
      if @expression.update_attributes expression_params
        format.html { redirect_to @expression, notice: 'Expression was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @expression.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /expressions/1
  # DELETE /expressions/1.json
  def destroy
    @expression.destroy
    respond_to do |format|
      format.html { redirect_to expressions_url }
      format.json { head :ok }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_expression
    @expression = Expression.find params[:id]
  end

  def expression_params
    params.require(:expression).permit :tag_id, :referent_id, :locale, :form
  end
end
