class ReferentsController < ApplicationController
    filter_access_to :all
    # Here's where we defer to different handlers for different types of referent
    @@HandlersByIndex = [ Referent, GenreReferent, RoleReferent, 
            ProcessReferent, IngredientReferent, UnitReferent, 
            SourceReferent, AuthorReferent, OccasionReferent, 
            PantrySectionReferent, StoreSectionReferent, ChannelReferent, ToolReferent ]
    @@HandlerClass = Referent

  # GET /referents
  # GET /referents.json
  def index
    @container = "container_collections"
    @itempartial = "referents/show_table_row"
    @results_partial = "index_stream_results"
    smartrender unless do_stream ReferentsCache
  end

  # GET /referents/1
  # GET /referents/1.json
  def show
    @referent = Referent.find(params[:id])
    smartrender
  end

  # Get a new referent based on the given tag id
  # GET /referents/new
  # GET /referents/new.json?tagid=1&mode={over,before,after}&parent=referentid
  def new
    # @tabindex = (params[:tabindex] || session[:tabindex] || 4).to_i

    handlerclass = "#{params[:type]}Referent".constantize # @@HandlersByIndex[@tabindex]
    @referent = handlerclass.new
    @referent.express (params[:tagid]) if params[:tagid]
    @typeselections = Tag.type_selections
    @typeselections.shift

    respond_to do |format|
      # format.html { render (@tabindex==11 ? "new_channel.html.erb" : "new") }
      format.json { 
        if params[:tagid]
          render json: [ { :title=>@referent.longname, :isLazy=>true, :key=>@referent.id, :isFolder=>false } ]
        else
          render json: { dlog: with_format("html") { render_to_string layout: false } }
        end
      }
    end
  end

  # GET /referents/1/edit
  def edit
      @referent = Referent.find(params[:id]) # .becomes(Referent)
      # @expressions = @referent.expressions
      @referent_type = @referent.typenum
      @typeselections = Tag.type_selections
      @typeselections.shift
      smartrender
  end

  # POST /referents?tagid=1&mode={over,before,after}&target=referentid
  # POST /referents.json?tagid=1&mode={over,before,after}&target=referentid
  def create
    if params[:tabindex] # Obsolete: coming from the old tag-organizing page
        @tabindex = params[:tabindex].to_i || 0
        handlerclass = @@HandlersByIndex[@tabindex]
        tagid = params[:tagid].to_i # Id of expression
        targetid = params[:target] ? params[:target].to_i : 0
    else
        handlerclass = "#{params[:type]}Referent".constantize # @@HandlersByIndex[@tabindex]
        param_key = ActiveModel::Naming.param_key(handlerclass)
        tagid = params[param_key][:tag_id]
        # params[param_key].delete :typenum
    end
    go = 0
    keyback = 0
    
    # This code will pertain when we get some kind of hierarchy back
    case params[:mode]
    when "before"
        @referent = handlerclass.create tag: tagid
        # @referent.express tagid, form: :canonical # Ensure it has a tag
        # Make a child of this node's parent, if any
        parentid = ((targetid > 0) && handlerclass.find(targetid).parent_id) || 0
        if parentid > 0
            parent = handlerclass.find parentid
            parent.add_child @referent
            parent.save
        end
        keyback = @referent.id
    when "after"
        # Make a child of this node
        @referent = handlerclass.create tag: tagid
        # @referent.express tagid, form: :canonical
        parent = handlerclass.find targetid
        parent.add_child @referent
        parent.save
        keyback = @referent.id
    when "child"
        debugger
    when "over"
        # "over" indicates to add the tag to the referent's expressions
        @referent = handlerclass.find params[:target].to_i
        @referent.express tagid
    end

    if params[:mode] == "over"
      # "over" indicates to add the tag to the referent's expressions
      @referent = handlerclass.find params[:target].to_i
      @referent.express tagid
    elsif params[:mode]
      @referent = handlerclass.create tag: tagid
      keyback = @referent.id
    else
      # The standard New Referent return has no mode
      @referent = handlerclass.new params[param_key]
    end

    if @referent && @referent.save
      if @referent.class==ChannelReferent # Need to assign user's tags, but only after it has an id
        @referent.user.update_attributes params[param_key][:user_attributes]
      end
      respond_to do |format|
        format.html { redirect_to @referent.becomes(Referent), notice: 'Referent was successfully created/aliased.' }
        format.json {
          if params[:tagid]
            render json: [{:title => @referent.longname, :isLazy => true, :key => keyback, :isFolder => false}], status: :created
          else
            render json: {done: true, notice: "Successfully created "+@referent.longname}, status: :created
          end
        }
      end
    else
      @typeselections = Tag.type_selections
      @typeselections.shift
      if name_error = @referent.errors["user.username"]
        @referent.errors.add :tag_token, name_error[0]
      end
      smartrender :action => :new
    end
  end
  
  def fix_expression_tokens tokens, tagtype
      return if !tokens
      tokens.keys.each do |key|
          attrlist = tokens[key]
          attrlist[:tag_token].sub! /^\'/, "\'#{tagtype.to_s}::"
      end
  end

  # PUT /referents/1
  # PUT /referents/1.json
  def update
    # @tabindex = session[:tabindex] || params[:tabindex] || 0
    # handlerclass = @@HandlersByIndex[@tabindex]
    @referent = Referent.find(params[:id]) # .becomes(Referent)
    param_key = ActiveModel::Naming.param_key(@referent.class)
    # Any free tags specified as tag tokens will need a type associated with them.
    # This is prepended to the string
    fix_expression_tokens params[param_key][:expressions_attributes], @referent.typenum
    respond_to do |format|
      # params[param_key].delete(:typenum)
      if @referent.update_attributes(params[param_key])
        format.html { redirect_to @referent.becomes(Referent), notice: 'Referent was successfully updated.' }
        format.json {
          # The Channels table shows users (which are the outward face of channels)
          if @referent.class == ChannelReferent
            selector = dom_id(@referent.user) # "#listrow_#{@referent.user.id}"
            element = @referent.user
          else
            selector = "#Referent#{@referent.id}"
            element = @referent.becomes(Referent)
          end
          render json: {
            done: true,
            popup: "Referent now updated to serve you better",
            replacements: [ [ selector, with_format("html") { view_context.render_seeker_item element } ] ]
          }
        }
      else
        @referent.becomes(Referent)
        @typeselections = Tag.type_selections
        @typeselections.shift
        format.html { render action: "edit" }
        format.json { render json: @referent.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /referents/1
  # DELETE /referents/1.json
  def destroy
    @tabindex = session[:tabindex] || params[:tabindex] || 0
    handlerclass = @@HandlersByIndex[@tabindex]
    @referent = handlerclass.find(params[:id])
    @referent.destroy

    respond_to do |format|
      format.html { redirect_to referents_url }
      format.json { head :ok }
    end
  end
  
  # /referents/connect?parent=&child=
  def add_child
      @tabindex = session[:tabindex] || params[:tabindex] || 0
      handlerclass = @@HandlersByIndex[@tabindex]
      parent = handlerclass.find params[:parentid].to_i
      child = handlerclass.find params[:childid].to_i
      parent.add_child child
  end
end
