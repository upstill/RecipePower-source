require './lib/controller_utils.rb'

class ListsController < ApplicationController

  def index
    seeker_result List, 'div.list_list'
  end

  def create
    puts "List#create params: "+params[:list].to_s+" for user '#{current_user.name}'"
    @list = List.assert params[:list][:name], current_user
    @list.save
    puts "Created list '#{@list.name}', owner: #{@list.owner.name}"
    redirect_to edit_list_path(@list)
  end

  def show
    @list = List.find(params[:id])
    response_service.title = "About #{@list.name}"
    smartrender
  end

  def update
  end

  def destroy
  end

  def new
    puts "current_user: "+current_user.name
    @list = List.new(owner_id: current_user.id)
  end

  def edit
    puts "List#edit params: "+params.to_s+" for user '#{current_user.name}'"
    @list = List.find params[:id]
    smartrender # area: "floating"
  end
end
