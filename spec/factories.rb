FactoryGirl.define do
  factory :user do
    username "foo"
    password "foobar"
    email { "#{username}@example.com" }
  end
end