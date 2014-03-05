FactoryGirl.define do
  factory :tag

  factory :user do
    username "foo"
    password "foobar"
    email { "#{username}@example.com" }
  end

  factory :ingredient_tag, class: :tag do
    typenum 4
  end

  factory :process_referent do
    ignore do
      name "Herve"
    end
    after(:build) do |ref, evaluator|
      ref.express create(:tag, typenum: 3, name: evaluator.name)
      ref.save
    end
  end

  factory :ingredient_referent do
    ignore do
      name "Herve"
    end
    after(:build) do |ref, evaluator|
      ref.express create(:ingredient_tag, name: evaluator.name)
      ref.save
    end
    # association :canonical_expression, factory: :ingredient_tag, name: "#{name}"
  end

  factory :recipe do
    # description "Some appropriate words"
    sequence(:title) { |n| "dish#{n}" }
    # title "#{description}"
    sequence(:url) { |n| "http://www.davidlebovitz.com/2008/11/rosy-poached-quince/dish#{n}" }
  end

  factory :reference do
    url "http://www.foodandwine.com/chefs/adam-erace"
  end

  sequence :rcptitle do |n|
    "dish#{n}"
  end

end