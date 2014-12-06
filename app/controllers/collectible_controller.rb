class CollectibleController < ApplicationController

  def collect
    if current_user
      update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
      if params[:oust]
        @decorator.remove_from_collection current_user.id
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
      unless @decorator.errors.any? || @decorator.collected_by?(current_user.id)
        @decorator.add_to_collection current_user.id
        @decorator.save unless request.method == "POST"
      end
      @decorator.save if @decorator.errors.empty? && (request.method == "POST")
      if post_resource_errors @decorator
        render :errors
      else
        if (request.method == "POST")
          render :update # Present JSON instructions for updating the item
        else
          response_service.title = @decorator.title.truncate(20) # Get title (or name, etc.) from the entity
          smartrender
        end
      end
    else
      flash[:error] = "You have to be logged in to tag things"
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
        flash[:popup]
        render :update
      end
    else
      flash[:alert] = "Can't locate #{params[:controller].singularize} ##{params[:id] || '<unknown>'}"
      render :errors
    end
  end
end
