require 'spec_helper'

describe Referent do

  it "should create a goat milk tag" do
    goat_milk_tag = create :goat_milk_tag
    goat_milk_tag.should == 3
    goat_milk_tag.name.should == "goat"
  end
end
