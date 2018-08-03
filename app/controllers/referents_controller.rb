class ReferentsController < CollectibleController
    filter_access_to :all
    # Here's where we defer to different handlers for different types of referent
    @@HandlersByIndex = [ Referent, GenreReferent, DishReferent, 
            ProcessReferent, IngredientReferent, UnitReferent, 
            SourceReferent, AuthorReferent, OccasionReferent, 
            PantrySectionReferent, StoreSectionReferent, nil, ToolReferent,
	nil, nil, nil, nil, nil, CourseReferent ]
    @@HandlerClass = Referent

  # GET /referents
  # GET /referents.json
  def index
    smartrender 
  end

  # GET /referents/1
  # GET /referents/1.json
  def show
    update_and_decorate # @referent = Referent.find(params[:id])
    smartrender
  end

  # Get a new referent based on the given tag id
  # GET /referents/new
  # GET /referents/new.json?tagid=1&mode={over,before,after}&parent=referentid
  def new
    # @tabindex = (params[:tabindex] || session[:tabindex] || 4).to_i

    handlerclass = "#{params[:type]}Referent".constantize # @@HandlersByIndex[@tabindex]
    @referent = handlerclass.new
    @referent.express(params[:tagid]) if params[:tagid]
    @typeselections = Tag.type_selections
    @typeselections.shift

    respond_to do |format|
      format.json { 
        if params[:tagid]
          render json: [ { :title=>@referent.longname, :isLazy=>true, :key=>@referent.id, :isFolder=>false } ]
        else
          render json: { dlog: with_format('html') { render_to_string layout: false } }
        end
      }
    end
  end

  # GET /referents/1/edit
  def edit
    update_and_decorate
    @decorator.object = @referent.becomes(@referent.class.base_class)
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

    keyback = 0
    
    # This code will pertain when we get some kind of hierarchy back
    case params[:mode]
    when 'before'
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
    when 'after'
        # Make a child of this node
        @referent = handlerclass.create tag: tagid
        # @referent.express tagid, form: :canonical
        parent = handlerclass.find targetid
        parent.add_child @referent
        parent.save
        keyback = @referent.id
    when 'child'
        # debugger
    when 'over'
        # "over" indicates to add the tag to the referent's expressions
        @referent = handlerclass.find params[:target].to_i
        @referent.express tagid
    end

    if params[:mode] == 'over'
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
      respond_to do |format|
        format.html { redirect_to @referent.becomes(Referent), notice: 'Referent was successfully created/aliased.' }
        format.json {
          if params[:tagid]
            render json: [{:title => @referent.longname, :isLazy => true, :key => keyback, :isFolder => false}], status: :created
          else
            render json: {done: true, notice: 'Successfully created '+@referent.longname}, status: :created
          end
        }
      end
    else
      @typeselections = Tag.type_selections
      @typeselections.shift
      if name_error = @referent.errors['user.username']
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
    @referent = Referent.find(params[:id]).becomes(Referent)
    # update_and_decorate
    attribute_params = params[ActiveModel::Naming.param_key(@referent.class)]
    # Any free tags specified as tag tokens will need a type associated with them.
    # This is prepended to the string
    fix_expression_tokens attribute_params[:expressions_attributes], @referent.typenum
    expressions_attributes =
        attribute_params[:expressions_attributes].values.find_all { |expression_attributes|
          expression_attributes['_destroy'] == 'false'
        }.collect { |expression_attributes|
          # Because the token can be either a tag id or a string, make sure to use only the string
          tagname = expression_attributes['tag_token']
          tagid = tagname.to_i
          tagname = ((t = Tag.find_by id: tagid) && t.name) if tagid != 0
          ([tagname] + expression_attributes.slice('referent_id', 'localename', 'formname').values).join('/')
        }
    if expressions_attributes.count != expressions_attributes.uniq.count
      # Error! Expressions must be unique
      @referent.errors.add :expressions, 'must be unique'
    end
    @decorator = @referent.decorate
    if @referent.errors.empty? && @referent.update_attributes(attribute_params)
      flash[:popup] = "'#{@referent.name}' now updated to serve you better"
      @update_items = [ :card ]
    else
      resource_errors_to_flash @referent, preface: "Couldn't save the #{@referent.typename}"
      render action: 'edit'
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
