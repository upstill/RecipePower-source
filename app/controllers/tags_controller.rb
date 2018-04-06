class TagsController < ApplicationController
  filter_access_to :all

  # GET /tags
  # GET /tags.xml
  def index
    response_service.title = 'Tags'
    # seeker_result Tag, 'div.tag_list' # , clear_tags: true
    # -1 stands for any type
    params[:tagtype] ||= 0 if response_service.admin_view?
    params.delete :tagtype if params[:tagtype] == "-1"
    smartrender
  end

  # POST /tags
  # POST /tags.xml
  # Since we don't actually create tags using the form, this action is used by the tags lister
  # to gather parameters for filtering the list. Thus, we collect the form data and redirect
  def create
    # We get the create action in two circumstances: 
    #  1) we actually are creating a new tag;
    #  2) we get called from the index page with a tag filter
    if params[:commit] =~ /Filter/
      redirect_to controller: "tags", action: "index", tag: params[:tag]
    else
      @tag = Tag.new(params[:tag])
      respond_to do |format|
        if @tag.save
          format.html { redirect_to controller: "tags",
                                    action: "index",
                                    tag: params[:tag],
                                    notice: 'Tag was successfully created.' }
          format.xml { render :xml => @tag, :status => :created, :location => @tag }
        else
          format.html { render :action => "new" }
          format.xml { render :xml => @tag.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # GET /tags/match
  # This action is for remotely querying the tags that match a given string. It gets used in:
  #  -- the tag editor, for filtering for unbound tags
  #  -- the recipe tagger, for applying tags to recipes
  #  -- recipe searching, for picking tags to search on
  # Expected returns are:
  #  -- JSON, for the client to create dynatree lists of tags for the tag editor
  #  -- html, for the resulting list of tags
  # The match action provides a list of tags that match a given string. 
  # Query parameters:
  #    :tagtype - type of tag to look for (if any; otherwise, unconstrained)
  #    :tagtype_x - type(s) of tag to avoid (if any; otherwise, unconstrained)
  #    :except - comma-delimited id(s) of tag to avoid
  #    :all - match all tags w/o regard to privacy
  #    :user_id - match only tags visible to the user (ignored by :all)
  #    :tabindex - index of tabs in the tags editor; convertible to tag type
  #             NB: tabindex may be omitted for other contexts; all types will be searched
  #    :unbound_only - if true, we're addressing a list of unbound tags, so 
  #                     eliminate all tags that already have a referent
  #    :q, :term - string to match within a tag
  #    :user_id - id of user who is viewing the list
  #    :makeormatch - Boolean indicating that this tag should be created if 
  #           it can't be found, modulo normalization
  def match
    matchstr = params[:q] || params[:term] || ""
    matchopts = {
        userid: (User.super_id if params[:all]) || params[:user_id] || (current_user && current_user.id) || User.guest_id,
        assert: (params[:makeormatch] == "true"),
        partition: true,
        fold: !params[:verbose]
    }
    if params[:tagtype]
      params[:tagtype] << ',0' if params[:untypedOK]
      matchopts[:tagtype] = params[:tagtype].split(',').map(&:to_i)
    elsif params[:tagtype_x]
      matchopts[:tagtype_x] = params[:tagtype_x].split(',').map(&:to_i)
    end
    @taglist = Tag.strmatch(matchstr, matchopts)
    # When searching over more than one type, we can disambiguate by showing the type of the resulting tag
    showtype = params[:showtype] # tagtype.nil? || (tagtype.is_a?(Array) && (tagtype.size>1))
    @taglist.delete_if { |t| !t.referents.empty? } if params[:unbound_only] == 'true'
    if except_ids = params[:except]
      except_ids = except_ids.split(',').map &:to_i
    end
    respond_to do |format|
      format.json { render :json =>
                               case params[:response_format]
                                 when 'dynatree'
                                   # for a dynatree list: an array of hashes with title, isLazy, key and isFolder fields
                                   @taglist.map { |tag| {:title => tag.name, :isLazy => false, :key => tag.id, :isFolder => false} }
                                 when 'strings'
                                   # Just a list of strings...
                                   @taglist.map &:name # (&:attributes).map { |match| match['name'] }
                                 else # assuming "tokenInput" because that js won't send a parameter
                                   # for tokenInput: an array of hashes, each with "id" and "name" values
                                   names_ids = @taglist.inject({}) { |memo, tag|
                                     (memo[tag.normalized_name] ||= []) << tag
                                     memo
                                   }
                                   results = []
                                   names_ids.each { |key, matches|
                                     disambiguate = (matches.count > 1) || params[:disambiguate]
                                     matches.each { |tag|
                                       results <<
                                           {
                                               id: tag.id,
                                               name: tag.typedname(disambiguate, ([1, 3].include? current_user_or_guest_id))
                                           } unless except_ids && (except_ids.include? tag.id)
                                     }
                                   }
                                   results
                               end
      }
      format.html { render partial: 'tags/taglist' }
      format.xml { render :xml => @taglist }
    end
  end

  # GET /tags/new
  # GET /tags/new.xml
  def new
    @tag = Tag.new
    smartrender
  end

  # GET /tags/1/edit
  def edit
    @tag = Tag.find(params[:id])
    smartrender
  end

  # GET /tags/1
  # GET /tags/1.xml
  def show
    # return if need_login true, true
    begin
      update_and_decorate
    rescue
      render text: "There is no tag #{params[:id]}. Where did you get that idea?"
    end
    if @tag
      session[:tabindex] = @tabindex
      smartrender
    end
  end

  def associated
    update_and_decorate
    response_service.title = @tag.name
    smartrender
  end

  # GET /tags/editor?tabindex=index
  # Return HTML for the editor for classifying tags
  def editor
    # return if need_login true, true
    @tabindex = params[:tabindex] ? params[:tabindex].to_i : (session[:tabindex] || 0)
    # The list of orphan tags gets all tags of this type which aren't linked to a table
    @taglist = Tag.strmatch('', userid: current_user.id, tagtype: Tag.index_to_type(@tabindex))
    session[:tabindex] = @tabindex
    render partial: 'editor'
  end

=begin
  # POST /id/absorb
  # Merge two tags together, returning a list of DOM elements to nuke as a result
  def absorb
    if !(@absorber = Tag.find params[:id])
      flash[:error] = 'Couldn\'t find tag to absorb into'
    elsif !(victim = Tag.find_by id: params[:victim])
      flash[:error] = 'Couldn\'t find tag to absorb'
    elsif (survivor = @absorber.absorb victim) && !(resource_errors_to_flash survivor, preface: "Couldn\'t absorb '#{victim.name}.")
      @to_delete = victim
    end
    respond_to do |format|
      format.html {}
      format.json {}
      format.js { render 'shared/get_content' }
    end
  end
=end

  # POST /id/associate
  # Associate the tag with another, according to params[:as]:
  #  -- 'synonym' means to make the tag a synonym of the other
  #  -- 'child' means to make the other a parent of the tag
  #  -- 'absorb' means to make the other vanish into the tag
  #  -- 'merge_into' means to vanish this tag into the other (inverse of absorb)
  def associate
    begin
      update_and_decorate
      if !(other = Tag.find_by id: params[:other])
        flash[:error] = 'Couldn\'t find tag to associate with'
      else
        @touched = [@tag, other]
        case params[:as]
          when 'merge_into'
            reporter = other.absorb @tag
            resource_errors_to_flash reporter, preface: "Couldn\'t merge into '#{other.name}."
          when 'absorb'
            reporter = @tag.absorb other
            resource_errors_to_flash reporter, preface: "Couldn\'t absorb '#{other.name}."
          when 'child' # Make the tag a child of the other
            reporter = TagServices.new(other).make_parent_of @tag
          when 'synonym' # Make the tag a synonym of the other
            reporter = other.absorb @tag, false
            resource_errors_to_flash reporter, preface: "Couldn\'t make a synonym of '#{@tag.name}."
        end
      end
    rescue
      flash[:error] = 'Couldn\'t find tag to associate'
    end
    @touched = [@tag, other, reporter].uniq
    respond_to do |format|
      format.html {}
      format.json { render }
      format.js { render 'shared/get_content' }
    end
  end

  # GET /typify
  # move the listed keys from one type to another
  def typify
    # Return array of ids of tags successfully converted
    # We can take an array of tagids or a single tagid together with a new type spec
    if params['tagids']
      puts "Typify"+params['tagids'].inspect
      idsChanged = Tag.convertTypesByIndex(params['tagids'].map { |p| p.delete('orphantag_').to_i }, params['fromtabindex'].to_i, params['totabindex'].to_i, true)
      # Go back to the client with a list of ids that were changed
      puts 'Success on '+idsChanged.inspect
    elsif params['tagid'] && params['typenum']
      # Change the type of a single tag
      # We ask and allow for the possibility that the tag will be absorbed into another
      # tag of the target type
      tag = (Tag.find params['tagid'].to_i).project params['typenum']
      idsChanged = tag.errors.empty? && [tag.id]
    end
    if idsChanged
      render :json => {deletions: idsChanged.map { |id| ["#tagrow_#{id.to_s}", "#tagrow_#{id.to_s}HR", ".absorb_#{id.to_s}"] }.flatten,
                       replacements: idsChanged.collect { |id|
                         if tag = Tag.find_by(id: id)
                           view_context.item_replacement tag, :table
                         end
                       }.compact,
                       popup: (tag ? "'#{tag.name}' now typed as '#{tag.typename}'" : 'Tags changed successfully')
             }
    else
      render :json => {}
    end
  end

  # PUT /tags/1
  # PUT /tags/1.xml
  def update
    @tag = Tag.find(params[:id])
    @decorator = @tag.decorate
    respond_to do |format|
      params[:tag][:tagtype] = params[:tag][:tagtype].to_i unless params[:tag][:tagtype].nil?
      if !(success = @tag.update_attributes(params[:tag])) && @tag.errors[:key]
        @tag = @tag.disappear
      end
      if @tag.errors.any?
        format.html { render :action => 'edit' }
        format.xml { render :xml => @tag.errors, :status => :unprocessable_entity }
      else
        flash[:popup] = 'Tag successfully updated'
        format.html { redirect_to(@tag, :notice => "Tag was successfully updated for type #{params[:tag][:tagtype].to_s} to #{@tag.typename}.") }
        format.json { render 'collectible/update', locals: { items: [:table, :card] } }
        format.xml  { head :ok }
      end
    end
  end

  def destroy
    if params[:ban]
      nn = Tag.where(id: params[:id]).pluck(:normalized_name).first
      BannedTag.create(normalized_name: nn) unless BannedTag.where(normalized_name: nn).exists?
    end
    super
  end

end
