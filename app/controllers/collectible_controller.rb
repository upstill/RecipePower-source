class CollectibleController < ApplicationController

  def collect
    if current_user
      update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
      if params[:oust]
        @decorator.collect false
        msg = "'#{@decorator.title.truncate(50)}' has been vanquished from your collection (though you may see it in others)."
      else
        @decorator.add_to_collection current_user.id
        msg = "'#{@decorator.title.truncate(50)}' now appearing in your collection."
      end
      @decorator.object.save
      if post_resource_errors(@decorator.object)
        render :errors
      else
        flash[:popup] = msg
        render :collect
      end
    else
      flash[:alert] = "Sorry, you need to be logged in to collect something."
      render :errors
    end
  end

  # GET tag
  # PATCH tag
  def tag
    if current_user
      update_and_decorate
      unless @decorator.errors.any? || @decorator.collected? # Ensure that it's collected before editing
        @decorator.collect
        unless request.method == "POST"
          @decorator.save
          flash.now[:notice] = "'#{@decorator.title.truncate(50)}' has been added to your collection for tagging" # if @decorator.object.errors.empty?
        end
      end
      @decorator.save if @decorator.errors.empty? && (request.method == "POST")
      if post_resource_errors @decorator
        render :errors
      else
        if (request.method == "POST")
          flash[:popup] = "#{@decorator.human_name} saved"
          render "collectible/update.json"
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
    if post_resource_errors @decorator.object
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
      if post_resource_errors(@decorator)
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
    post_resource_errors(@decorator.object) if @decorator
    render :errors # This won't be invoked directly by a user, so there's nothing else to render
  end

  # Absorb another collectible of the same type, denoted by params[:other_id]
  # NB: obviously, this only works if the specific collectible has an absorb method
  def absorb
    if update_and_decorate && params[:other_id] && (other = @decorator.object.class.find(params[:other_id].to_i))
      @absorbee = other.decorate
      @decorator.absorb other
      ResultsCache.bust session.id
      other.destroy
    end
  end
end
