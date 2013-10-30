class TagsController < ApplicationController
  filter_access_to :all
  
  # GET /tags
  # GET /tags.xml
  def index
    @Title = "Tags"
    collection_result Tag, clear_tags: true
  end
  
  def query
    @Title = "Tags"
    collection_result Tag
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
      @Title = "Tags"
      @tag = Tag.new(params[:tag])
      respond_to do |format|
        if @tag.save
          format.html { redirect_to controller: "tags", 
                            action: "index", 
                            tag: params[:tag],
                            notice: 'Tag was successfully created.' }
          format.xml  { render :xml => @tag, :status => :created, :location => @tag }
        else
          format.html { render :action => "new" }
          format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
        end
      end
    end
  end
  
=begin
# Shouldn't be using this anymore
# GET /tags/list?tabindex=index
# Return HTML for the list of tags (presumably called by the tags tablist)
  def list
    # return if need_login true, true
    @Title = "Tags"
    if params[:tagtype]
        tagtype = params[:tagtype].to_i
    else
        @tabindex = params[:tabindex] ? params[:tabindex].to_i : (session[:tabindex] || 0)
        # The list of orphan tags gets all tags of this type which aren't linked to a table
        tagtype = @tabindex > 0 ? Tag.index_to_type(@tabindex) : 0
        session[:tabindex] = @tabindex
    end
    if true
        @taglist = Tag.where(tagtype: tagtype).order("id").page(params[:page]).per_page(5)
    else
        @taglist = Tag.strmatch("", userid: session[:user_id], tagtype: tagtype)
    end
    render partial: "alltags"
  end
=end

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
  #    :tabindex - index of tabs in the tags editor; convertible to tag type
  #             NB: tabindex may be omitted for other contexts; all types will be searched
  #    :unbound_only - if true, we're addressing a list of unbound tags, so 
  #                     eliminate all tags that already have a referent
  #    :q, :term - string to match within a tag
  #    :user_id - id of user who is viewing the list
  #    :makeormatch - Boolean indicating that this tag should be created if 
  #           it can't be found, modulo normalization
  def match
      @Title = "Tags"
      @tabindex = params[:tabindex].to_i # params[:tabindex] ? params[:tabindex].to_i : (session[:tabindex] || 0)
      # session[:tabindex] = @tabindex
      # Get tagtype directly from tagtype parameter, or indirectly from tabindex (or leave it nil)
      tagtype = (params[:tagtype] && params[:tagtype].to_i) || 
                (params[:tagtypes] && params[:tagtypes].split(',').collect{ |t| t.to_i} ) ||
                (params[:tabindex] && @tabindex)
      # If a tagtype is asserted AND type 0 is admissable, search on an array of types
      tagtype = [0, tagtype] if params[:untypedOK] && tagtype          
      matchstr = params[:q] || params[:term] || ""
      matchopts = {
          userid: params[:user_id] || session[:user_id],
          tagtype: tagtype,
          assert: (params[:makeormatch] == "true"),
          partition: true
      }
      @taglist = Tag.strmatch(matchstr, matchopts).uniq
      @taglist.delete_if { |t| !t.referents.empty? } if params[:unbound_only] == "true"
      respond_to do |format|
        format.json { render :json => 
            case params[:response_format]
            when "dynatree"
                # for a dynatree list: an array of hashes with title, isLazy, key and isFolder fields
                @taglist.map { |tag| { :title=>tag.name, :isLazy=>false, :key=>tag.id, :isFolder=>false } }
            when "strings"
                # Just a list of strings...
                @taglist.map(&:attributes).map { |match| match["name"] }
            else # assuming "tokenInput" because that js won't send a parameter
                # for tokenInput: an array of hashes, each with "id" and "name" values
                @taglist.map(&:attributes).map { |match| {:id=>match["id"], :name=>match["name"]} } 
            end
        }
        format.html { render partial: "tags/taglist" }
        format.xml  { render :xml => @taglist }
      end
  end

  # GET /tags/1
  # GET /tags/1.xml
  def show
      # return if need_login true, true
      @Title = "Tags"
    @tag = Tag.find(params[:id])
    session[:tabindex] = @tabindex

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tag }
    end
  end

  # GET /tags/new
  # GET /tags/new.xml
  def new
      @Title = "Tags"
    @tag = Tag.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @tag }
    end
  end

  # GET /tags/1/edit
  def edit
    @Title = "Tags"
    @tag = Tag.find(params[:id])
  end
  
  # GET /tags/editor?tabindex=index
  # Return HTML for the editor for classifying tags
  def editor
    # return if need_login true, true
    @Title = "Tags"
    @tabindex = params[:tabindex] ? params[:tabindex].to_i : (session[:tabindex] || 0)
    # The list of orphan tags gets all tags of this type which aren't linked to a table
    @taglist = Tag.strmatch("", userid: session[:user_id], tagtype: Tag.index_to_type(@tabindex) )
    session[:tabindex] = @tabindex
    render partial: "editor"
  end
  
  # GET /id/absorb
  # Merge two tags together, returning a list of DOM elements to nuke as a result
  def absorb
    absorber = Tag.find params[:id].to_i
    victim = Tag.find params[:victim].to_i
    survivor = victim.disappear_into absorber 
    if survivor.errors.empty?
      victimidstr = ((survivor == victim) ? absorber : victim).id.to_s
      render :json=>{
        deletions: ["#tagrow_#{victimidstr}", "#tagrow_#{victimidstr}HR", ".absorb_#{victimidstr}"]
      }
    else
      render :json=>{errors: survivor.errors }
    end
  end
  
  # GET /typify
  # move the listed keys from one type to another
  def typify
      # Return array of ids of tags successfully converted
      # We can take an array of tagids or a single tagid together with a new type spec
      if params["tagids"] 
          puts "Typify"+params["tagids"].inspect
          idsChanged = Tag.convertTypesByIndex(params["tagids"].map{|p| p.delete("orphantag_").to_i}, params["fromtabindex"].to_i, params["totabindex"].to_i, true)
          # Go back to the client with a list of ids that were changed
          puts "Success on "+idsChanged.inspect
      elsif params["tagid"] && params["typenum"]
          # Change the type of a single tag
          # We ask and allow for the possibility that the tag will be absorbed into another 
          # tag of the target type
          tag = (Tag.find params["tagid"].to_i).project params["typenum"]
          idsChanged = tag.errors.empty? && [tag.id]
      end
      if idsChanged
        render :json=>{ deletions: idsChanged.map{ |id| ["#tagrow_#{id.to_s}", "#tagrow_#{id.to_s}HR", ".absorb_#{id.to_s}"] }.flatten ,
                        popup: (tag ? "'#{tag.name}' now typed as '#{tag.typename}'" : "Tags changed successfully")
        }
      else
        render :json => { }
      end
  end

  # PUT /tags/1
  # PUT /tags/1.xml
  def update
    @Title = "Tags"
    @tag = Tag.find(params[:id])
    debugger
    respond_to do |format|
puts "Tag controller converting "+params[:tag][:tagtype].to_s
      params[:tag][:tagtype] = params[:tag][:tagtype].to_i unless params[:tag][:tagtype].nil?
puts "...to "+params[:tag][:tagtype].to_s
      if !(success = @tag.update_attributes(params[:tag])) && @tag.errors[:key]
        @tag = @tag.disappear
      end
      if !@tag.errors.any?
        format.html { redirect_to(@tag, :notice => "Tag was successfully updated for type #{params[:tag][:tagtype].to_s} to #{@tag.typename}.") }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /tags/1
  # DELETE /tags/1.xml
  def destroy
    @Title = "Tags"
    @tag = Tag.find(params[:id])
    @tag.destroy

    respond_to do |format|
      format.html { redirect_to(tags_url) }
      format.xml  { head :ok }
    end
  end
end
