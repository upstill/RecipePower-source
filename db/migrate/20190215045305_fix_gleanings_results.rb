# This migration updates the Results attribute of Gleanings for more robust serialization
# The Results class has a new serializer that stores its Result values as a
# pair: the id of the Finder that produced the result, and an array of output values.
# (The old serialization was a plain YAML dump that included all Result objects
# with all their instance variables, including the Site)
class FixGleaningsResults < ActiveRecord::Migration[5.0]
  def up
		rename_column :gleanings, :results, :results_old
		add_column :gleanings, :results, :text
		to_fix = Gleaning.where('results_old LIKE ?', '%ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Integer%')
    # Fix this unparseable data type in all the gleanings
		to_fix.each do |gl|
			gl.update_attribute :results_old, gl.results_old.gsub('ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Integer', 'ActiveModel::Type::Integer')
		end
		# Now that results_old can be YAML-loaded in Rails 5,
		# convert Gleaning#results to a more serialization-friendly
		Gleaning.where.not(results_old: nil).each do |gl|
			gl.results = YAML.load gl.results_old
			gl.save
		end
	end

	# Restore the old results attribute
	def down
		remove_column :gleanings, :results
		rename_column :gleanings, :results_old, :results
	end
end
