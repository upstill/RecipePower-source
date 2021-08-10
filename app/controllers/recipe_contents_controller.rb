require 'parsing_services.rb'
class RecipeContentsController < ApplicationController
  before_action :set_recipe, only: [:show, :edit, :update, :destroy, :annotate, :tag]
  before_action :login_required

  def edit
  end

  # Actions for getting and accepting a new tag
  # POST submits new tag
  # GET returns form
  def tag
    rcparams = params[:recipe][:recipeContents]
    @content = rcparams[:content]
    if params[:button_name] != 'Cancel' && rcparams[:tagname]  # No tag parameters => open dialog
      # If the submission is successful, we redirect to #annotate
      if rcparams[:tagname].blank?
        @recipe.errors.add :base, "You need to name that name!"
      elsif tag = Tag.assert(rcparams[:tagname], Tag.typenum(rcparams[:tagtype]), extant_only: true)
        flash[:popup] = "Name was there all along."
      elsif !(tag = Tag.assert rcparams[:tagname], Tag.typenum(rcparams[:tagtype]))
        @recipe.errors.add :base, 'Couldn\'t make new name'
      elsif tag.errors.any?
        # Report errors and re-enter dialog
        @recipe.errors.add :base, tag.full_messages
      else
        flash[:popup] = "'#{tag.name}' successfully added as #{tag.typename}!"
      end
    end
    # We open the tag dialog if this is the initial call, or a Save failed
    @form_name, @form_title = 'newtag_form', 'Define New Name' if rcparams[:tagname].nil? || @recipe.errors.any?
    render :annotate
  end

  # Modify the content HTML to mark a selection with a parsing tag
  def annotate
    redirect_to :show unless rcparams = params[:recipe][:recipeContents]
    @content = rcparams[:content]
    tag if rcparams[:token] == 'tag'
    ps = ParserServices.new entity: @recipe, input: @content
    # This is a two-, possibly three-phase process:
    # 1) a selection from the browser directs attention to a range of text, which generates a CSS path for an element to parse
    # 2) this so-called parse_path is attempted to be parsed. If it doesn't work because of a findable tag, a dialog is presented
    #    for the user to decide how to handle the tag;
    # 3) the user says to enter the problematic tag directly into the dictionary, or specifies an existing tag for what
    #    was meant by the problematic tag. The latter can be optionally entered as a synonym of the intended name.
    if rcparams[:anchor_path].present? # Initial annotation on browser selection
      logger.debug "Annotating with anchor_path = '#{rcparams[:anchor_path]}'"
      @annotation, @parse_path = ps.annotate_selection *rcparams.values_at(:token, :anchor_path, :anchor_offset, :focus_path, :focus_offset)
    elsif @parse_path = rcparams[:parse_path] # Specifying an element of the DOM
      if !(@tagname = rcparams[:tagname])
        logger.debug "Looking for tag at '#{@parse_path}'"
        @annotation = ps.parse_on_path @parse_path do |tagtype, tagname|
          @tagtype, @tagname = tagtype, tagname
        end
        if @tagname
          @form_name = 'tagtype_form'
        else
          @parse_path = nil
        end
      else # There IS a tagname: use that as a tag
        noko_elmt = ps.extract_via_path @parse_path
        @tagtype = rcparams[:tagtype]
        @annotation = rcparams[:content]
        # @tagname of type @tagtype is a mystery tag previously identified by a failed parse.
        if params[:button_name] != 'Cancel'
          logger.debug "Use tag '#{@tagname}' of type '#{@tagtype}' at path '#{@parse_path}'"
          # The logic here is as follows, for sorting out words.
          # -- '@tagname' is the questionable tag
          # -- 'rcparams[:replacement]' is the id of a tag selected by the user to serve in its place
          # -- 'rcparams[:assert]' is set if that tag will be added to the dictionary
          # If there's no replacement tag, the term is just accepted into the dictionary as a new instance of the tagtype.
          # If there IS a non-nil replacement, that's what we understand the term to mean. If, then, assert is set,
          # the questionable term will get added to the dictionary as a synonym for the replacement. If not, the alias
          # is accepted and added to the Seeker as such.
          # No tagname has been parsed out; proceed to parse the entity denoted by the parse path
          if (replacement = rcparams[:replacement]).present?
            old_tag = Tag.find_by id: replacement
            if rcparams[:assert]
              new_tag = Tag.assert @tagname, @tagtype
              new_tag.absorb old_tag, false
            end
            value = old_tag.name
          else
            # No replacement provided => simply assert the tag into the dictionary
            value = @tagname
            Tag.assert @tagname, @tagtype
          end
        end
        @tagname = nil # Go back to the annotation dialog
        @parse_path = nil
        if noko_elmt
          noko_elmt[:value] = value
          @annotation = noko_elmt.ancestors.last.to_s
        end
      end
    end
  end

  def update
  end

  def create
  end

  def post
  end

  def destroy
  end

  def show
    x=2
  end

  def set_recipe
    @recipe = Recipe.find params[:id]
  end
end
