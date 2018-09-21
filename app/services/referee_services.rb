class RefereeServices

  def initialize(referee)
    # An referee is any object that a Referent accepts as a referee (via the Referments join table)
    @referee = referee
  end

  # Ensure a Pagerefable referee matches the kind of its page ref
  # Return the original object (if the kind matches) or a new, matching object
  def assert_kind kind
    page_ref =
    case @referee
      when PageRef
        return @referee if @referee.kind == kind
        @referee
      when Pagerefable # Recipe, Site
        @referee.page_ref
      else
        @referee.errors.add :referment, "won't translate to #{kind}"
        return @referee
    end
    case kind
      when 'recipe'
        # We want a recipe, but the current referee is not a recipe
        # Either the page_ref will have an associated recipe, or we make one
        return page_ref.recipes.first || Recipe.new(page_ref: page_ref)
      when 'site'
        return page_ref.sites.first || Site.new(page_ref: page_ref)
      else # All other kinds are simply a type of PageRef. We convert and return
        page_ref.kind = kind
        return page_ref
    end
  end
end