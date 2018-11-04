class Referment < ApplicationRecord

  # attr_accessible :referent, :referent_id, :referee, :referee_type, :referee_id

  # Virtual attributes for creating the referee
  # attr_accessible :url, :kind, :title
  attr_accessor :url, :kind, :title

  belongs_to :referent
  belongs_to :referee, :polymorphic => true, validate: true

  def title
    case referee
      when Referent
        referee.name
      when nil
        @title
      else
        referee.title
    end
  end

  def url
    case referee
      when Referent
        nil
      when nil
        @url
      else
        referee.decorate.url
    end
  end

  def kind
    case referee
      when Referent
        nil
      when PageRef
        referee.kind
      when Recipe
        'recipe'
      when Site
        'site'
      when nil
        'article'
    end
  end

end
