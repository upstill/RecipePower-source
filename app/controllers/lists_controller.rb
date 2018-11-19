class ListsController < CollectibleController
  before_filter :login_required, :except => [:touch, :index, :show, :associated, :capture, :collect, :card, :contents ]

  def index
    @active_menu = :other_lists
    response_service.title =
    case @access = params[:access]
      when 'owned'
        @active_menu = :my_lists
        'My Lists'
      when 'collected'
        @empty_msg = 'As you add other people\'s lists to your collection, they will appear here.'
        'Collected Lists'
      when 'all'
        'Every List There Is'
      else
        'Available Lists'
    end
    smartrender 
  end

  def edit
    update_and_decorate
    smartrender
  end

  def create
    @first_entity = params[:entity_type].singularize.camelize.constantize.find(params[:entity_id]) rescue nil
    response_service.title = 'New List'
    puts "List#create params: "+params[:list].to_s+" for user '#{current_user.name}'"
    l = List.assert( params[:list][:name], current_user)
    update_and_decorate l, touch: true, update_attributes: !l.persisted?

    if l.persisted?
      flash[:popup] = "Found list '#{@list.name}'."
    else
      flash[:popup] ="Successfully created '#{@list.name}'."
    end
    @list.save
    ListServices.new(@list).include @first_entity, current_user.id if @first_entity
    # respond_to do |format|
      # format.html { redirect_to tag_list_path(@list), :status => :see_other, notice: notice }
  end

  def contents
    update_and_decorate touch: true
    response_service.title = "About #{@list.name}"
    @empty_msg = 'This list is empty now, but you can add any item by editing that item'
    @active_menu = (@list.owner == current_user) ? :my_lists : :other_lists
    smartrender 
  end

  def show
    contents
  end

  def update
    if update_and_decorate
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
    update_and_decorate
    name = @list.name
    selector = "tr##{@decorator.dom_id}"
    @list.destroy
    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { render json: { redirect: root_path, popup: "'#{name}' destroyed"} }
      format.js   { render action: "destroy", locals: { selector: selector, name: name } }
    end
  end

  def new
    @first_entity = params[:entity_type].singularize.camelize.constantize.find(params[:entity_id]) rescue nil
    update_and_decorate List.new(owner_id: params[:owner_id].to_i || current_user.id), touch: true
    smartrender
  end

  def pin
    update_and_decorate
    if current_user
      begin
        ls = ListServices.new @list
        @entity = params[:entity_type].singularize.camelize.constantize.find params[:entity_id]
        if @deleted = (params[:oust] && params[:oust] == "true")
          ls.exclude @entity, current_user.id
          flash[:popup] = "Now gone from #{@list.name}" if @list.errors.empty?
        else
          ls.include @entity, current_user.id
          flash[:popup] = "Now appearing in #{@list.name}" if @list.errors.empty?
        end
      rescue
        flash[:alert] = "Can't pin #{params[:entity_type]} ##{params[:entity_id]}"
      end
    else
      flash[:alert] = "Sorry, you need to be logged in to add to a list"
    end
  end

  private

  def list_params
    permitted_attributes = List.mass_assignable_attributes + [
        :ordering, :title, :owner_id, # :owner, # Specified by id
        :name, # :name_tag_id, :name_tag, # Specified by name
        :tags, :included_tag_tokens, :pullin, :notes, :description,
        :availability
    ]
    params.require(:list).permit *permitted_attributes
  end

end
