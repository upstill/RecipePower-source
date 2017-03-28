class Finder < ActiveRecord::Base
  attr_accessible :label, :selector, :attribute_name, :site, :site_id
  belongs_to :site


  def attributes_hash
    { id: id, label: label, selector: selector, attribute_name: attribute_name, site: site, site_id: site_id}
  end

  def labelsym
    @labelsym ||= label.downcase.gsub /\s/, '_'
  end

  def what
    (label == 'RSS Feed') ? :feeds : label.underscore.pluralize
  end
end
