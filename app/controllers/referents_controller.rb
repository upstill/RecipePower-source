class ReferentsController < CollectibleController
  before_action :set_referent, only: [:show, :edit, :update, :destroy]
  filter_access_to :all
  # Here's where we defer to different handlers for different types of referent
  @@HandlersByIndex = [Referent, GenreReferent, DishReferent,
                       ProcessReferent, IngredientReferent, UnitReferent,
                       SourceReferent, AuthorReferent, OccasionReferent,
                       PantrySectionReferent, StoreSectionReferent, nil, ToolReferent,
                       nil, nil, nil, nil, nil, CourseReferent]
  @@HandlerClass = Referent

  # GET /referents
  # GET /referents.json
  def index
    smartrender
  end

  # GET /referents/1
  # GET /referents/1.json
  def show
    update_and_decorate
    smartrender
  end

  # Get a new referent based on the given tag id
  # GET /referents/new
  # GET /referents/new.json?tagid=1&mode={over,before,after}&parent=referentid
  def new
    handlerclass = "#{params[:type]}Referent".constantize
    @referent = handlerclass.new
    @referent.express(params[:tagid]) if params[:tagid]
    @typeselections = Tag.type_selections
    @typeselections.shift

    respond_to do |format|
      format.json {
        if params[:tagid]
          render json: [{:title => @referent.longname, :isLazy => true, :key => @referent.id, :isFolder => false}]
        else
          render json: {dlog: with_format('html') {render_to_string layout: false}}
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
    handlerclass = "#{params[:type]}Referent".constantize
    param_key = ActiveModel::Naming.param_key(handlerclass)
    tagid = params[param_key][:tag_id]

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
        format.html {redirect_to @referent.becomes(Referent), notice: 'Referent was successfully created/aliased.'}
        format.json {
          if params[:tagid]
            render json: [{:title => @referent.longname, :isLazy => true, :key => keyback, :isFolder => false}], status: :created
          else
            render json: {done: true, notice: 'Successfully created ' + @referent.longname}, status: :created
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
    @referent = @referent.becomes Referent
    rp = referent_params
    # Any free tags specified as tag tokens will need a type associated with them.
    # This is prepended to the string
    fix_expression_tokens rp[:expressions_attributes], @referent.typenum
    expressions_attributes =
        rp[:expressions_attributes].values.find_all {|expression_attributes|
          expression_attributes['_destroy'] == 'false'
        }.collect {|expression_attributes|
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
    # ...and on to the referments.
    @decorator = @referent.decorate
    @presenter = present @referent
    # The referment params require special processing
    rfmt_params = rp.delete :referments_attributes
    # We hold the name_tag_token back until the expressions get processed,
    # so the expressions' local and form pertain
    name_tag_token = rp.delete :name_tag_token
    @referent.update_attributes rp
    @referent.name_tag_token = name_tag_token # Saved until after expressions are set
    @referent.save if @referent.errors.blank? && ReferentServices.new(@referent).parse_referment_params(rfmt_params)
    if @referent.errors.empty?
      @referent.reload
      flash[:popup] = "'#{@referent.name}' now updated to serve you better"
      @replacements = [ view_context.summarize_referent_replacement(@referent) ]
      @update_items = [:card]
    else
      resource_errors_to_flash @referent, preface: "Couldn't save the #{@referent.typename}"
      render action: 'edit'
    end
  end

  # DELETE /referents/1
  # DELETE /referents/1.json
  def destroy
    @referent.destroy
    respond_to do |format|
      format.html {redirect_to referents_url}
      format.json {head :ok}
    end
  end

  # /referents/connect?parent=&child=
  def add_child
    parent = Referent.find params[:parentid].to_i
    child = Referent.find params[:childid].to_i
    parent.add_child child
  end

  private

  def set_referent
    @referent = Referent.find params[:id]
  end

  def referent_params
    params.require(:referent).permit!
  end
end
