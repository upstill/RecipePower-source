class PageRefDecorator < CollectibleDecorator
  # include Templateer
  # delegate_all

  def self.attrmap
    super.merge(picurl: :image).except :page_ref_kind, :type
  end

  # Ensure that the entity has its displayable data updated
  def regenerate_dependent_content
    # The page_ref will produce different output if the site's trimmers have changed
    site.trimmers_changed?
  end

=begin
  def request_dependencies *newly_needed
    # If we haven't persisted, then the page_ref has no connection back
    page_ref.recipes << self unless persisted? || page_ref.recipes.to_a.find { |r| r == self }
    page_ref.request_attributes *(newly_needed & [ :picurl, :title, :description ]) # Those to be got from PageRef
    page_ref.request_attributes :recipe_page if newly_needed.include?(:content)
    super *newly_needed if defined? super
  end
=end

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

end
