class ExpressionsController < ApplicationController
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
    @expression = Expression.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @expression }
    end
  end

  # GET /expressions/new
  # GET /expressions/new.json
  def new
    @expression = Expression.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @expression }
    end
  end

  # GET /expressions/1/edit
  def edit
    @expression = Expression.find(params[:id])
  end

  # POST /expressions
  # POST /expressions.json
  def create
    @expression = Expression.new(params[:expression])

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
    @expression = Expression.find(params[:id])

    respond_to do |format|
      if @expression.update_attributes(params[:expression])
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
    @expression = Expression.find(params[:id])
    @expression.destroy

    respond_to do |format|
      format.html { redirect_to expressions_url }
      format.json { head :ok }
    end
  end
end
