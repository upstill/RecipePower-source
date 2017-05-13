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
    new = pres.summarize_aspect :owners, helper: :homelink
    Capybara.string(new).should have_css('div div p.pull-left span', text: @admin.name)
  end

  it 'presents similars' do
    j2 = tags(:jal2)
    j3 = tags(:jal3)
    pres = TagPresenter.new j2, view, @admin
    expect(pres.tagserv.lexical_similars).to eq [j3]
    presentation = pres.summarize_aspect :lexical_similars, helper: :summarize_tag_similar, label: 'Similars', absorb_btn: true
=begin
    if pres.respond_to? :similars_summary
      old = pres.similars_summary label: 'Similars', absorb_btn: true
      old.should eq(presentation)
    end
=end
    cs = Capybara.string(presentation)
    cs.should have_css('span span', text: j3.name)
    cs.should have_css("form input[value='Absorb']")
  end

  it 'presents children' do
    tp = TagPresenter.new(tags(:dessert), view, @admin)
    presentation = tp.summarize_aspect :children, label: 'Category Includes: '
    if @presenter.respond_to? :children_summary
      old = tp.children_summary unique: true
      old.should eq(presentation)
    end
    Capybara.string(presentation).should have_css('a.submit', text: 'pie')
    Capybara.string(presentation).should have_css('a.submit', text: 'gateau')
  end

  it 'presents parents' do
    tp = TagPresenter.new(tags(:cake), view, @admin)
    presentation = tp.summarize_aspect :parents, label: 'Categorized Under: '
    if @presenter.respond_to? :parents_summary
      old = tp.parents_summary unique: true
      old.should eq(presentation)
    end
    Capybara.string(presentation).should have_css('a.submit', text: 'dessert')
  end

  it 'presents referents' do
    presentation = @presenter.summarize_aspect :referents,
                                      :helper => :summarize_referent,
                                      label: 'All Meaning(s)'
    if @presenter.respond_to? :referents_summary
      old = @presenter.referents_summary unique: false
      old.should eq(presentation)
    end
    Capybara.string(presentation).should have_css('a.submit', text: 'pie')
    Capybara.string(presentation).should have_css('a.submit', text: 'pies')
  end

  it 'presents references' do
    probe = @presenter.summarize_aspect(:definition_page_refs, :helper => :present_definition, :label => 'reference')
    Capybara.string(probe).should have_css('strong', text: 'desserts')
  end

  it 'presents synonyms' do
    tp = TagPresenter.new tags(:dessert), view, @admin
    probe = tp.summarize_aspect :synonyms, helper: :summarize_tag_similar, absorb_btn: true, joiner: '<br>'
    Capybara.string(probe).should have_css('a', text: "desserts")
  end

end
