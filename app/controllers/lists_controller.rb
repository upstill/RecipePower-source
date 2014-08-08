require './lib/controller_utils.rb'
require './lib/querytags.rb'

class ListsController < ApplicationController

  def index
    # seeker_result Reference, 'div.reference_list' # , clear_tags: true
    @container = "container_collections"
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
      format.html { redirect_to edit_list_path(@list), :status => :see_other, notice: notice }
      format.json {
        render json: {
          done: true,
          dlog: with_format('html') { render_to_string partial: "lists/edit_modal" },
          popup: notice }
      }
    end
  end

  def show
    @list = List.find(params[:id])
    response_service.title = "About #{@list.name}"
    smartrender unless do_stream ListCache, "show_masonry_item"
  end

  def update
    @list = List.find params[:id]
    if @list.update_attributes(params[:list])
      respond_to do |format|
        format.html { redirect_to lists_url, :status => :see_other, notice: "'#{list.name}' was successfully updated." }
        format.json { render json: {
            done: true,
            replacements: [ [ "#list"+@list.id.to_s, with_format("html") { render_to_string partial: "lists/show_table_row" } ] ],
            popup: "List saved" }
        }
      end
    else
      respond_to do |format|
        format.html { render action: "edit" }
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

  def edit
    puts "List#edit params: "+params.to_s+" for user '#{current_user.name}'"
    @list = List.find params[:id]
    smartrender # area: "floating"
  end
end
