require './lib/controller_utils.rb'
require './lib/querytags.rb'

class ListsController < CollectibleController

  def index
    # seeker_result Reference, 'div.reference_list' # , clear_tags: true
    @active_menu = :other_lists
    response_service.title =
    case params[:access]
      when "owned"
        @active_menu = :my_lists
        "My Lists"
      when "collected"
        "More Lists"
      when "all"
        "Every List There Is"
      else
        "Available Lists"
    end
    smartrender unless do_stream ListsCache
  end

  def edit
    update_and_decorate
    smartrender
  end

  def create
    response_service.title = "New List"
    puts "List#create params: "+params[:list].to_s+" for user '#{current_user.name}'"
    update_and_decorate List.assert( params[:list][:name], current_user)
    flash[:popup] = @list.id ? "Found list '#{@list.name}'." : "Successfully created '#{@list.name}'."
    @list.save
    # respond_to do |format|
      # format.html { redirect_to tag_list_path(@list), :status => :see_other, notice: notice }
  end

  def show
    update_and_decorate
    response_service.title = "About #{@list.name}"
    @empty_msg = "This list is empty now, but you can add any item that has an 'Add to...' button"
    @active_menu = (@list.owner == current_user) ? :my_lists : :other_lists
    smartrender unless do_stream ListCache
  end

  def update
    @list.save if update_and_decorate
    if @list.errors.empty?
      flash[:popup] = "'#{@list.name}' all saved now"
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
      format.html { redirect_to root_path }
      format.json { render json: { redirect: root_path, popup: "'#{name}' destroyed"} }
      format.js   { render action: "destroy", locals: { selector: selector, name: name } }
    end
  end

  def new
    update_and_decorate List.new(owner_id: params[:owner_id].to_i || current_user.id)
    smartrender
  end

  def pin
    update_and_decorate
    if @list.owner != current_user
      flash[:alert] = "Sorry, you can't pin to someone else's board"
    else
      begin
        @list.include params[:entity_type].singularize.camelize.constantize.find(params[:entity_id])
        @list.save
        flash[:popup] = "Now appearing in #{@list.name}" if @list.errors.empty?
      rescue
        flash[:alert] = "Can't pin #{params[:entity_type]} ##{params[:entity_id]}"
      end
    end
  end

end
