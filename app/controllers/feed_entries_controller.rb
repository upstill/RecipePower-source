class FeedEntriesController < CollectibleController

  def tag
    update_and_decorate
  end

  def update
    update_and_decorate
    if @feed_entry.errors.empty? && @feed_entry.save
      flash[:popup] = "Feed Entry is saved"
      render :ack_popup
    else
      render :action => 'edit', :notice => "Huhh??!?"
    end
  end
end
