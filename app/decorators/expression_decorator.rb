class ExpressionDecorator  < Draper::Decorator
  delegate_all

  def self.ref_check
    bogus_ref_ids = Expression.all.pluck(:referent_id).uniq - Referent.all.pluck(:id)
    Expression.where(referent_id: bogus_ref_ids).map &:destroy
  end
end