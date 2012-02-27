class TagsController < ApplicationController
  layout "recipes"
  # GET /tags
  # GET /tags.xml
  def index
      if params[:tabindex]
          @tabindex = params[:tabindex].to_i
          tagtype = Tag.index_to_type @tabindex 
      else
          @tabindex = session[:tabindex] || 0
          tagtype = params[:tagtype] || :any
      end
      session[:tabindex] = @tabindex
      @tags = (tagtype == :any) ? Tag.all : Tag.where("tagtype = ?", tagtype)
      # The :unbound_only parameter limits the set to tags with no associated form (and, thus, referent)
      @tags.delete_if { |t| !t.referents.empty? } if params[:unbound_only] == "true"
    respond_to do |format|
      format.json { render :json => @tags.map { |tag| { :title=>tag.name+tag.id.to_s, :isLazy=>false, :key=>tag.id, :isFolder=>false } } }
      format.html # index.html.erb
      format.xml  { render :xml => @tags }
    end
  end
  
  # GET /tags/match
  # The match action provides a list of tags that match a given string. 
  # Query parameters:
  #    :tagtype - type of tag to look for
  #    :tabindex - index of tabs in the tags editor; convertible to tag type
  #    :unbound_only - if true, we're compiling a list of unbound tags, so 
  #                     eliminate all tags that already have a referent
  #    :q, :term - string to match within a tag
  #    :makeormatch - Boolean indicating that this tag should be created if 
  #           it can't be found EXACTLY
  def match
      if params[:tabindex]
          @tabindex = params[:tabindex].to_i
          tagtype = Tag.index_to_type @tabindex 
      else
          @tabindex = session[:tabindex] || 0
          tagtype = params[:tagtype] || :any
      end
      session[:tabindex] = @tabindex
      @orphantags = Tag.strmatch(params[:q] || params[:term] || "", 
                               session[:user_id],
                               tagtype,
                               params[:makeormatch] == "true")
      @orphantags.delete_if { |t| !t.referents.empty? } if params[:unbound_only] == "true"
      respond_to do |format|
        format.json { render :json => 
                case params[:response_format]
                when "dynatree"
                    # for a dynatree list: an array of hashes with title, isLazy, key and isFolder fields
                    @orphantags.map { |tag| { :title=>tag.name, :isLazy=>false, :key=>tag.id, :isFolder=>false } }
                when "strings"
                    # Just a list of strings...
                    @orphantags.map(&:attributes).map { |match| match["name"] }
                else # assuming "tokenInput" because that js won't send a parameter
                    # for tokenInput: an array of hashes, each with "id" and "name" values
                    @orphantags.map(&:attributes).map { |match| {:id=>match["id"], :name=>match["name"]} } 
                end
        }
        format.html { render :partial=>"tags/taglist"}
        format.xml  { render :xml => @orphantags }
      end
  end

  # GET /tags/1
  # GET /tags/1.xml
  def show
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
    @tag = Tag.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @tag }
    end
  end

  # GET /tags/1/edit
  def edit
    @tag = Tag.find(params[:id])
  end
  
  # GET /tags/editor?tabindex=index
  # Return HTML for the editor for classifying tags
  def editor
    return if need_login true
    @tabindex = (params[:tabindex] || 0).to_i # type numbers for Ingredient, Genre, Free Tag, etc.
    # The list of orphan tags gets all tags of this type which aren't linked to a table
    @orphantags = Tag.strmatch("", session[:user_id], Tag.index_to_type(@tabindex), false)
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
    @tag = Tag.find(params[:id])
    @tag.destroy

    respond_to do |format|
      format.html { redirect_to(tags_url) }
      format.xml  { head :ok }
    end
  end
end
