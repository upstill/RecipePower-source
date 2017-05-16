require 'spec_helper'

# Specs in this file have access to a helper object that includes
# the TokenInputHelper. For example:
#
# describe TokenInputHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
describe TokenInputHelper do
  # include RSpecHtmlMatchers
  # fixtures :tags

  it 'replicates token_input_query' do

    test_options = {
        class: 'a_class',
        rows: 2,
        autofocus: false,
        # :hint => 'Select a synonym',
        # :placeholder => 'Your Synonym Here',
        # :'min-chars' => 3,
        # :'no-results-text' => 'Nothing to see here...',
        handler: 'querify',
        tagtype: '10,12'
    }
    ti_old = helper.token_input_query test_options
    html_old = HTML::Document.new(ti_old).root
    ti_new = helper.token_input_element 'querytags', test_options
    html_new = HTML::Document.new(ti_new).root
    html_old.should eq(html_new)

  end

  it 'converts tagtype param to query' do

    # Default
    ti = helper.token_input_element 'querytags'
    expect(ti).to have_tag('input', :with => { :id => 'querytags' })

    # Passing string
    ti = helper.token_input_element 'querytags', tagtype: '10'
    expect(ti).to have_tag('input', :with => { :id => 'querytags', 'data-query' => 'tagtype=10' })

    # Passing single type
    ti = helper.token_input_element 'querytags', tagtype: 10
    expect(ti).to have_tag('input', :with => { :id => 'querytags', 'data-query' => 'tagtype=10' })

    # Passing single type symbol
    ti = helper.token_input_element 'querytags', tagtype: :StoreSection
    expect(ti).to have_tag('input', :with => { :id => 'querytags', 'data-query' => 'tagtype=10' })

    # Passing string array
    ti = helper.token_input_element 'querytags', tagtype: ['10', '12']
    expect(ti).to have_tag('input', :with => { :id => 'querytags', 'data-query' => 'tagtype=10,12' })

    # Passing single type array
    ti = helper.token_input_element 'querytags', tagtype: [10, 12]
    expect(ti).to have_tag('input', :with => { :id => 'querytags', 'data-query' => 'tagtype=10,12' })

    # Passing single type symbol array
    ti = helper.token_input_element 'querytags', tagtype: [:StoreSection, :Tool]
    expect(ti).to have_tag('input', :with => { :id => 'querytags', 'data-query' => 'tagtype=10,12' })
  end
end