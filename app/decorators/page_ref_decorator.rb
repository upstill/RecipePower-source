class PageRefDecorator < CollectibleDecorator
  # include Templateer
  # delegate_all

  def self.attrmap
    super.merge(picurl: :image).except :page_ref_kind, :type
  end

  # Ensure that the entity has its displayable data updated
  def regenerate_dependent_content
    # The page_ref will produce different output if the site's trimmers have changed
    refresh_attributes :content if site.trimmers_changed?
  end

  def human_name plural=false, capitalize=true
    name = object.kind.humanize
    name = name.pluralize if plural
    capitalize ? name : name.downcase
  end

  def title
    (object.title if object.title.present?) || (url if url.present?) || '<unknown title>'
  end

  def image
    object.picurl
  end

  def image=img
    object.picurl = img
  end

  def external_link
    url
  end

  # The name for the decorator devolves to the PageRef's type, since
  # we may be dealing with a subclass of PageRef
  def class_name
    type
  end

  def eligible_tagtypes
    ([ :Ingredient, :Genre, :Occasion, :Dish, :Process, :Tool, :Course, :Diet ] + super).uniq
  end

  # Accept attribute values extracted from a page:
  # 1: hand them off to the gleaning
  # 2: adopt them back from there
  def adopt_extractions extraction_params={}
    return unless extraction_params
    as_attributes = {}
    extraction_params.keys.each do |key|
      if attrname = attribute_name_for(key)
        as_attributes[attrname] = extraction_params[key]
      end
    end
    if as_attributes.present?
      # Translate the extractions parameters into an attribute hash
      build_gleaning unless gleaning
      # Assign all attributes that are either open or untracked
      gleaning.assign_attributes gleaning.assignable_values(as_attributes)
      assign_attributes assignable_values(as_attributes)
    end
  end

end
