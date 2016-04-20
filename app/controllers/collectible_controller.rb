class CollectibleController < ApplicationController

  def collect
    if current_user
      update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
      msg = @decorator.title.truncate 50
      if params.has_key? :private
        @decorator.be_collected true
        @decorator.collectible_private = params[:private]
        msg << (@decorator.private ? ' now' : ' no longer')
        msg << ' hidden from others.'
      end
      if params.has_key? :in_collection
        was_collected = @decorator.collectible_collected?
        @decorator.be_collected params[:in_collection]
        @newly_deleted = !(@newly_collected = @decorator.collectible_collected?) if @decorator.collectible_collected? != was_collected
        msg << (@decorator.collectible_collected? ?
            ' now appearing in your collection.' :
            ' has been ousted from your collection (though you may see it elsewhere).')
      end
      @decorator.object.save
      if resource_errors_to_flash(@decorator.object)
        render :errors
      else
        flash[:popup] = msg
        render :collect
      end
    else
      flash[:alert] = "Sorry, you need to be logged in to collect anything."
      render :errors
    end
  end

  # Replace the set of lists that the entity is on (as viewed by the current user)
  def lists
    if current_user
      update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
      msg = @decorator.title.truncate 50
      if request.method == 'GET'
        render :lists
      else
        @decorator.object.save
        if resource_errors_to_flash(@decorator.object)
          render :errors
        else
          flash[:popup] = "'#{msg}' treasured."
          render 'collectible/update.json'
        end
      end
    else
      flash[:alert] = 'Sorry, you need to be logged in to manage treasuries.'
      render :errors
    end
  end

  def editpic
    update_and_decorate
    @golinkid = params[:golinkid]
    @fallback_img = params[:fallback_img]
    gleaning =
    if @pageurl = params[:url]
      Gleaning.glean @pageurl, 'Image'
    elsif @decorator.object.is_a?(Linkable) && @decorator.glean!
      @decorator.gleaning
    else
      Gleaning.glean @decorator, 'Image'
    end
    @pic_select_list = view_context.pic_picker_select_list gleaning.images
    if @pageurl && @pic_select_list.blank?
      flash.now[:error] = 'Sorry, we couldn\'t get any images from there.'
      render :errors
    end
  end

  # GET tag
  # PATCH tag
  def tag
    if current_user
      params.delete :recipe if request.method == "GET" # We're not saving anything otherwise
      update_and_decorate
      unless @decorator.errors.any? || @decorator.collectible_collected? # Ensure that it's collected before editing
        @decorator.be_collected
        @decorator.save
        flash.now[:notice] = "'#{@decorator.title.truncate(50)}' has been added to your collection for tagging" # if @decorator.object.errors.empty?
      end
      if resource_errors_to_flash @decorator, preface: 'Couldn\'t save.'
        render :errors
      else
        unless request.method == 'GET'
          flash[:popup] = "#{@decorator.human_name} saved"
          render 'collectible/update.json'
        else
          response_service.title = @decorator.title.truncate(20) # Get title (or name, etc.) from the entity
          smartrender
        end
      end
    else
      flash[:error] = "You have to be logged in to tag anything"
      render :errors
    end
  end

  def update
    update_and_decorate
    if resource_errors_to_flash @decorator.object
      render :edit
    else
      flash[:popup] = "#{@decorator.human_name} is saved"
      render :update
    end
  end

  # DELETE /feeds/1
  # DELETE /feeds/1.json
  def destroy
    if update_and_decorate
      @decorator.destroy
      if resource_errors_to_flash(@decorator)
        render :errors
      else
        flash[:popup] = "#{@decorator.human_name} is no more."
        render :update
      end
    else
      flash[:alert] = "Can't locate #{params[:controller].singularize} ##{params[:id] || '<unknown>'}"
      render :errors
    end
  end

  # Register that the entity was touched by the current user.
  # Since that entity will now be at the head return a new first item in the list.
  def touch
    # If all is well, make sure it's on the user's list
    if update_and_decorate(@entity) # May be defined by a subclass before calling up the chain
      if current_user
        current_user.touch @decorator.object
        flash[:popup] = "Snap! Touched #{@decorator.human_name} #{@decorator.title}." unless params[:silent]
      else
        flash[:alert] = "Sorry, you need to be logged in to touch a #{@decorator.human_name}" unless params[:silent]
      end
    end
    resource_errors_to_flash(@decorator.object) if @decorator
    render :errors # This won't be invoked directly by a user, so there's nothing else to render
  end

  # Absorb another collectible of the same type, denoted by params[:other_id]
  # NB: obviously, this only works if the specific collectible has an absorb method
  def absorb
    if update_and_decorate && params[:other_id] && (other = @decorator.object.class.find(params[:other_id].to_i))
      @absorbee = other.decorate
      @decorator.absorb other
      ResultsCache.bust response_service.uuid
      other.destroy
    end
  end

  def edit
    update_and_decorate
    smartrender
  end

  def show
    update_and_decorate
    response_service.title = @decorator && @decorator.title.truncate(20)
    @nav_current = nil
    smartrender
  end

  def associated
    show
  end

end
