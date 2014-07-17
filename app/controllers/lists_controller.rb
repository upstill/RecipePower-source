require './lib/controller_utils.rb'

class ListsController < ApplicationController

  def index
    seeker_result List, 'div.list_list'
  end

  def create
    response_service.title = "New List"
    puts "List#create params: "+params[:list].to_s+" for user '#{current_user.name}'"
    @list = List.assert params[:list][:name], current_user
    @list.description = params[:list][:description]
    @list.typenum = params[:list][:typenum]
    if @list.id
      flash[:notice] = "#{@list.name} already exists"
    else
      @list.save
    end
    puts "Created list '#{@list.name}', owner: #{@list.owner.name}"
    notice = "Successfully created '#{@list.name}'."
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
    smartrender
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
    @list.destroy
    respond_to do |format|
      format.html { render action: "index" }
      format.json { render json: { deletions: ["tr#list#{@list.id}"], popup: "'#{name}' destroyed"} }
      format.js {
        render action: "destroy", locals: { selector: "tr#list#{@list.id}", name: name }
      }
    end
  end

  def new
    puts "current_user: "+current_user.name
    @list = List.new(owner_id: current_user.id)
    smartrender
  end

  def edit
    puts "List#edit params: "+params.to_s+" for user '#{current_user.name}'"
    @list = List.find params[:id]
    smartrender # area: "floating"
  end
end
