# encoding: UTF-8
require 'test_helper'
class ImportTest < ActiveSupport::TestCase 
  test "Flours" do
	LinkRef.import_CSVfile "db/data/Test/flours.csv"
	
	# Get and test the tag and referent for 'flours'
	flours = Tag.strmatch("flours", tagtype: 4)
	assert flours, "Couldn't get tag for 'flours'"
	parent = flours.meaning
	assert_equal "flours", parent.name, "flours referent doesn't refer back"
	parent2 = Referent.express "flours", 4
	assert_equal parent.id, parent2.id, "Fetching 'flours' and expressing 'flours' yielded different referents"
	
	# Get and test the tag and referent for 'flours'
	wheat = Tag.strmatch("wheat flour", tagtype: 4)
	assert wheat, "Couldn't get tag for 'wheat flour'"
	child = wheat.meaning
	assert_equal "wheat flour", child.name, "'wheat flour' referent doesn't refer back"
	child2 = Referent.express "wheat flour", 4
	assert_equal parent.id, parent2.id, "Fetching 'flours' and expressing 'flours' yielded different referents"
	
  end
end