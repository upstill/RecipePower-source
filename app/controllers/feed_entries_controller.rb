class FeedEntriesController < ApplicationController
  def collect
    update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
    current_user.collect @feed_entry if current_user
    redirect_to tag_feed_entry_url(@feed_entry, mode: :modal)
  end

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
