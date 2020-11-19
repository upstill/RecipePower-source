class ReferentPolicy < CollectiblePolicy

=begin
  def index?
    super
  end

  def create?
    super
  end

  def new?
    super
  end

  def edit?
    super
  end

  def show?
    super
  end

  def update?
    super
  end

  def destroy?
    super
  end
=end

=begin

  def associated?
    super
  end

  def editpic?
    super
  end

  def glean?
    super
  end

  def touch?
    super
  end

  def collect?
    super
  end

  def card?
    super
  end

  def tag?
    super
  end

  def lists?
    true
  end

=end

end

class SourceReferentPolicy < ReferentPolicy
end

class InterestReferentPolicy < ReferentPolicy
end

class GenreReferentPolicy < ReferentPolicy
end

class RoleReferentPolicy < ReferentPolicy
end

class DishReferentPolicy < ReferentPolicy
end

class CourseReferentPolicy < ReferentPolicy
end

class ProcessReferentPolicy < ReferentPolicy
end

class IngredientReferentPolicy < ReferentPolicy
end

class UnitReferentPolicy < ReferentPolicy
end

class AuthorReferentPolicy < ReferentPolicy
end

class OccasionReferentPolicy < ReferentPolicy
end

class PantrySectionReferentPolicy < ReferentPolicy
end

class StoreSectionReferentPolicy < ReferentPolicy
end

class DietReferentPolicy < ReferentPolicy
end

class ToolReferentPolicy < ReferentPolicy
end

class NutrientReferentPolicy < ReferentPolicy
end

class CulinaryTermReferentPolicy < ReferentPolicy
end

class QuestionReferentPolicy < ReferentPolicy
end

class ListReferentPolicy < ReferentPolicy
end

class EpitaphReferentPolicy < ReferentPolicy
end

class CourseReferentPolicy < ReferentPolicy
end

class TimeReferentPolicy < ReferentPolicy
end


