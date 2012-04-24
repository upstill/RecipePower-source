class TagsController < ApplicationController
  # GET /tags
  # GET /tags.xml
  def index
      return if need_login true, true
      @Title = "Tags"
      @tabindex = params[:tabindex] ? params[:tabindex].to_i : (session[:tabindex] || 0)
      session[:tabindex] = @tabindex
      @tags = params[:tagtype] ? Tag.where("tagtype = ?", params[:tagtype]) : Tag.all
      # The :unbound_only parameter limits the set to tags with no associated form (and, thus, referent)
      @tags.delete_if { |t| !t.referents.empty? } if params[:unbound_only] == "true"
    respond_to do |format|
      format.json { render :json => @tags.map { |tag| { :title=>tag.name+tag.id.to_s, :isLazy=>false, :key=>tag.id, :isFolder=>false } } }
      format.html # index.html.erb
      format.xml  { render :xml => @tags }
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
  #    :tabindex - index of tabs in the tags editor; convertible to tag type
  #             NB: tabindex may be omitted for other contexts; all types will be searched
  #    :unbound_only - if true, we're addressing a list of unbound tags, so 
  #                     eliminate all tags that already have a referent
  #    :q, :term - string to match within a tag
  #    :makeormatch - Boolean indicating that this tag should be created if 
  #           it can't be found, modulo normalization
  def match
      @Title = "Tags"
      @tabindex = params[:tabindex].to_i # params[:tabindex] ? params[:tabindex].to_i : (session[:tabindex] || 0)
      # session[:tabindex] = @tabindex
      # Get tagtype directly from tagtype parameter, or indirectly from tabindex (or leave it nil)
      tagtype = (params[:tagtype] && params[:tagtype].to_i) || 
                (params[:tabindex] && @tabindex)
      matchstr = params[:q] || params[:term] || ""
      matchopts = {
          userid: session[:user_id],
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
        format.html { render :partial=>"tags/taglist" }
        format.xml  { render :xml => @taglist }
      end
  end

  # GET /tags/1
  # GET /tags/1.xml
  def show
      return if need_login true, true
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
    return if need_login true, true
    @Title = "Tags"
    @tabindex = params[:tabindex] ? params[:tabindex].to_i : (session[:tabindex] || 0)
    # The list of orphan tags gets all tags of this type which aren't linked to a table
    @taglist = Tag.strmatch("", userid: session[:user_id], tagtype: Tag.index_to_type(@tabindex) )
    session[:tabindex] = @tabindex
    render :partial=>"editor"
  end
  
  # GET /typify
  # move the listed keys from one type to another
  def typify
      # Return array of ids of tags successfully converted
      puts "Typify"+params["tagids"].inspect
      idsChanged = Tag.convertTypesByIndex(params["tagids"].map{|p| p.delete("orphantag_").to_i}, params["fromtabindex"].to_i, params["totabindex"].to_i, true)
      # Go back to the client with a list of ids that were changed
      puts "Success on "+idsChanged.inspect
      render :json=>idsChanged.map { |id| orphantagid(id) }
  end

  # POST /tags
  # POST /tags.xml
  def create
      @Title = "Tags"
    @tag = Tag.new(params[:tag])

    respond_to do |format|
      if @tag.save
        format.html { redirect_to(@tag, :notice => 'Tag was successfully created.') }
        format.xml  { render :xml => @tag, :status => :created, :location => @tag }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /tags/1
  # PUT /tags/1.xml
  def update
      @Title = "Tags"
    @tag = Tag.find(params[:id])

    respond_to do |format|
puts "Tag controller converting "+params[:tag][:tagtype].to_s
      params[:tag][:tagtype] = params[:tag][:tagtype].to_i unless params[:tag][:tagtype].nil?
puts "...to "+params[:tag][:tagtype].to_s
      if @tag.update_attributes(params[:tag])
        @tag.save
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
