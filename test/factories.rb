FactoryBot.define do
  factory :tag

  factory :admin do
    email { 'fake@bogus.com' }
    password "password"
    password_confirmation "password"
    confirmed_at Date.today
  end

  factory :user do
    username "foo"
    password "foobar"
    email { "#{username}@example.com" }
  end

  factory :ingredient_tag, class: :tag do
    typenum 4
  end

  factory :process_referent do
    transient do
      name "Herve"
    end
    canonical_expression { create(:tag, typenum: 3, name: name) }
=begin
    after(:build) do |ref, evaluator|
      ref.express create(:tag, typenum: 3, name: evaluator.name)
      ref.save
    end
=end
  end

  factory :ingredient_referent do
    transient do
      name "Herve"
    end
    canonical_expression { create(:ingredient_tag, name: name) }
    after(:build) do |ref, evaluator|
      ref.express ref.canonical_expression
    end
    # association :canonical_expression, factory: :ingredient_tag, name: "#{name}"
  end

  factory :recipe do
    sequence(:url) { |n| "http://www.davidlebovitz.com/2008/11/rosy-poached-quince/dish#{n}" }
    # description "Some appropriate words"
    sequence(:title) { |n| "dish#{n}" }
    # title "#{description}"
  end

  factory :list, class: List do
    collectible_user_id 3
    collectible_comment 'this would be a comment'
    name_tag_id 15
    description 'compiling something'
    notes 'notes would go here'
    availability 2
    included_tag_tokens "11"
    pullin 1
    tagging_user_id 3
    editable_dish_tag_tokens "4"
    editable_ingredient_tag_tokens "3"
    tagging_list_tokens "1"

  end

  factory :page_ref, class: PageRef do
    url "http://www.foodandwine.com/chefs/adam-erace"
  end

  sequence :rcptitle do |n|
    "dish#{n}"
  end

end
