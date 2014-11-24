require './lib/controller_utils.rb'
require './lib/querytags.rb'

class ListsController < ApplicationController

  def index
    # seeker_result Reference, 'div.reference_list' # , clear_tags: true
    @active_menu = :other_lists
    smartrender unless do_stream ListsCache
  end

  def create
    response_service.title = "New List"
    puts "List#create params: "+params[:list].to_s+" for user '#{current_user.name}'"
    @list = List.assert params[:list][:name], current_user
    @list.description = params[:list][:description]
    @list.typenum = params[:list][:typenum]
    if @list.id
      notice = "Found list '#{@list.name}'."
    else
      notice = "Successfully created '#{@list.name}'."
    end
    @list.save
    respond_to do |format|
      format.html { redirect_to tag_list_path(@list), :status => :see_other, notice: notice }
      format.json {
        render json: {
          done: true,
          dlog: with_format('html') { render_to_string partial: "lists/tag_modal" },
          popup: notice }
      }
    end
  end

  def show
    @list = List.find(params[:id])
    response_service.title = "About #{@list.name}"
    @active_menu = (@list.owner == current_user) ? :my_lists : :other_lists
    smartrender unless do_stream ListCache
  end

  def update
    update_and_decorate
    if @list.errors.empty?
      flash[:notice] = "'#{@list.name}' was saved."
      respond_to do |format|
        format.html { redirect_to list_url(@list), :status => :see_other }
        format.json { render :update }
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: @list.errors[:all], status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @list = List.find params[:id]
    name = @list.name
    selector = "tr##{dom_id @list}"
    @list.destroy
    respond_to do |format|
      format.html { render action: "index" }
      format.json { render json: { deletions: [ selector ], popup: "'#{name}' destroyed"} }
      format.js   { render action: "destroy", locals: { selector: selector, name: name } }
    end
  end

  def new
    @list = List.new(owner_id: params[:owner_id].to_i || current_user.id)
    smartrender
  end

  def tag
    update_and_decorate
    smartrender 
  end
end
