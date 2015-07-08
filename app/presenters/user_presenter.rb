class String
  def if_empty fallback=nil
    empty? ? fallback : self
  end
end

class UserPresenter < CardPresenter
  presents :user
  delegate :username, :fullname, :handle, :lists, :feeds, to: :user

  def card_avatar_fallback
    image_path "default-avatar-128.png"
  end

  # Present the user's avatar, optionally with a form for uploading the image (if they're the viewer)
  def card_avatar with_form=false
    if is_viewer? and with_form
      with_format("html") { render "form_image", user: user }
    else
      super()
    end
  end

  def member_since
    user.created_at.strftime("%B %e, %Y")
  end

  def is_viewer?
    @viewer && (@viewer.id == user.id)
  end

  def linked_name
    card_object_link(user.fullname.present? ? user.fullname : user.username)
  end

  def card_header_content
    mail_link = link_to_submit("Send email", mailto_user_path(user, mode: :modal), button_size: "xs") unless is_viewer?
    ("#{fullname.downcase}&nbsp;#{content_tag(:small, username)}&nbsp;#{mail_link}").html_safe
  end

  # Provide a list of aspects for display in the entity's panel, suitable for passing to aspect
  def card_aspects
    [
        # :member_since,
        :name_form,
        :about,
        :owned_lists,
        :latest_recipe,
        :latest_list,
        :desert_island,
        :question,
        # :collected_lists,
        # :collected_feeds
    ]
  end

  def card_aspects1
    [
        # :member_since,
        :name_form,
        :owned_lists,
        :desert_island,
        :question,
        # :collected_lists,
        # :collected_feeds
    ]
  end

  def card_aspects2
    [
        :latest_recipe,
        :latest_list
    ]
  end

  def card_aspects3
    [
        :about
    ]
  end

  def card_aspect which
    label = contents = nil
    case which
      when :name_form
        if is_viewer? && user.fullname.blank?
          label = "Human Name"
          contents = with_format("html") { render "form_fullname", user: user }
        end
      when :member_since
        contents = member_since
      when :about
        contents = show_or_edit which, user.about
      when :collected_feeds
        label = "Following the feeds"
        contents = strjoin(feeds.collect { |feed|
                            link_to_submit feed.title, feed_path(feed)
                          }).html_safe
      when :collected_lists, :owned_lists
        if which == :owned_lists
          lists = user.visible_lists @viewer
          label = "Author of the lists"
        else
          lists = user.collected_entities List, @viewer
          label = "Following the lists"
        end
        unless lists.empty?
          contents = strjoin(
              lists.collect { |list|
                link_to_submit list.name, list_path(list)
              }).html_safe
        end
      when :desert_island
        if is_viewer?
          # Pick a desert-island selection for querying, one that the user hasn't filled in before if poss.
          unless tag_selection = user.tag_selections.where(tag_id: nil).to_a.sample
            if tsid = (Tagset.pluck(:id)-user.tag_selections.pluck(:tagset_id)).sample
              tag_selection = TagSelection.new user: user, tagset_id: tsid
            else
              tag_selection = user.tag_selections.to_a.sample
            end
          end
          contents = with_format("html") { render "form_tag_selections", tag_selection: tag_selection }
        elsif tag_selection = user.tag_selections.where.not(tag_id: nil).to_a.sample
          contents = tag_selection.tag.name
        end
        label = "My desert-island #{tag_selection.title}" if contents
      when :question
        # Pick a question and include a form for answering
        # Choose a question at random, preferring one that's as yet unanswered
        if is_viewer?
          all_qids = Tag.where(tagtype:15).pluck(:id) # IDs of all questions
          qid = (all_qids - user.answers.where.not(answer: "").pluck(:question_id)).sample || all_qids.sample
          answer = user.answers.find_or_initialize_by(question_id: qid)
          contents = with_format("html") { render "form_answers", answer: answer }
        elsif answer = user.answers.where.not(answer: "").to_a.sample
          contents = answer.answer
        end
        label = answer.question.name if answer
      when :latest_recipe
        label = "Latest Recipe"
        if latestrr = user.collection_pointers.where(:entity_type => "Recipe", :in_collection => true).order(created_at: :desc).first
          latest = latestrr.entity
          contents = collectible_show_thumbnail latest.decorate
        else
          contents = "No recipes yet—so install the #{link_to_submit 'Cookmark Button', '/popup/starting_step2', :mode => :modal} and go get some!"
        end
      when :latest_list
        label = "Latest List"
        if latest = user.owned_lists.order(updated_at: :desc).first
          contents = link_to_submit latest.name, list_path(latest)
        else
          contents = "To create your first list, click #{link_to_submit "here", new_list_path, :mode => :modal}."
        end
    end
    [ label, contents ]
  end

  def show_or_edit which, val
    if is_viewer?
      if val.present?
        (user.about + link_to_submit("Edit", edit_user_path(section: which), button_size: "xs")).html_safe
      else
        aspect_editor which
      end
    else
      val if val.present?
    end
  end

  def about
    handle_none user.about do
      markdown(user.about)
    end
  end

  def tags
    user.tags.collect { |tag| tag.name }.join(', ')
  end

  private

  def handle_none(value)
    if value.present?
      yield
    else
      h.content_tag :span, "None given", class: "none"
    end
  end

end
