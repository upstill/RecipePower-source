class Finder < ApplicationRecord
  # attr_accessible :label, :selector, :attribute_name, :site, :site_id
  if Rails::VERSION::STRING[0].to_i < 5
    belongs_to :site
  else
    belongs_to :site, optional: true
  end

  def attributes_hash
    { id: id, label: label, selector: selector, attribute_name: attribute_name, site_id: site_id }
  end

  def labelsym
    @labelsym ||= label.downcase.gsub /\s/, '_'
  end

  def what
    (label == 'RSS Feed') ? :feeds : label.underscore.pluralize
  end

  # Return the list of newline-separated selectors denoted by the selector
  def selectors
    selector.split /\n/
  end
end
