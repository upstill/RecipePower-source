require 'spec_helper'
# require TagPresenter

describe TagPresenter do
  fixtures :tags
  fixtures :referents
  fixtures :expressions

  include Devise::TestHelpers

  def setup
    @admin = FactoryGirl.create(:admin)
    @request.env["devise.mapping"] = Devise.mappings[:admin]
    sign_in @admin
  end

  before do
    # setup
    @presenter = TagPresenter.new tags(:pie), view, @admin
    @admin = FactoryGirl.create(:user)
  end

  it "presents name" do
    #expect(@presenter.name false, false).to eq("desserts")
    # subject { Capybara.string(@presenter.name(false, false)) }
    # it { should have_css('strong', text: "desserts") }
    Capybara.string(@presenter.name(false, false)).should have_css('strong', text: "pie")
    # @presenter.name(false, false).to_s.should have_css('strong', text: "desserts")
  end

  it 'presents owners' do
    pres = TagPresenter.new tags(:jal2), view, @admin
    pres.tag.admit_user @admin.id  # Add an owner
    Capybara.string(pres.owners_summary).should have_css('div div p.pull-left span', text: @admin.name)
  end

  it 'presents similars' do
    j2 = tags(:jal2)
    j3 = tags(:jal3)
    pres = TagPresenter.new j2, view, @admin
    expect(pres.tagserv.lexical_similars).to eq [j3]
    cs = Capybara.string(pres.similars_summary label: 'Similars', absorb_btn: true)
    cs.should have_css('span span', text: j3.name)
    cs.should have_css("form input[value='Absorb']")
  end

  it 'presents children' do
    tpstring = TagPresenter.new(tags(:dessert), view, @admin).children unique: true
    Capybara.string(tpstring).should have_css('a.submit', text: 'pie')
    Capybara.string(tpstring).should have_css('a.submit', text: 'cake')
  end

  it 'presents parents' do
    tpstring = TagPresenter.new(tags(:cake), view, @admin).parents_summary unique: true
    Capybara.string(tpstring).should have_css('a.submit', text: 'dessert')
  end

  it 'presents referents' do
    tpstring = @presenter.referents false
    Capybara.string(tpstring).should have_css('a.submit', text: 'pie')
    Capybara.string(tpstring).should have_css('a.submit', text: 'pies')
  end

  it 'presents references' do
    Capybara.string(@presenter.references_summary).should have_css('strong', text: 'desserts')
  end

  it 'presents synonyms' do
    tp = TagPresenter.new tags(:dessert), view, @admin
    Capybara.string(tp.synonyms_summary).should have_css('a', text: "desserts")
  end

end
