require 'result.rb'

class Results < HashWithIndifferentAccess

  def initialize *labels
    labels.each { |label| self[label] = [] }
  end

  def results_for label
    (self[label] || []).map(&:out).flatten.compact.map { |result|
      # Allowing for non-String results
      result.is_a?(String) ? result.strip.if_present : result
    }.compact.uniq
  end

  def result_for label
    results_for(label).first
  end

  def report_for label
    self[label]&.map &:report
  end

  # We accept method calls named after the labels
  def method_missing(meth, *args, &block)
    label = meth.to_s.gsub('_', ' ')
    label = label.singularize if is_plural = (label == label.pluralize)
    if label = (labels.find { |candidate| candidate.downcase == label }) || label.capitalize
      return is_plural ? results_for(label) : result_for(label)
    end
    super
  end

  alias_method :labels, :keys

  def assert_result label, val_or_vals
    # We keep these asserted results in Results with no finderdata
    unless prior = (self[label] ||= []).find { |result| result.finderdata.nil? }
      self[label].unshift (prior = Result.new)
    end
    prior.out = val_or_vals.is_a?(Array) ? val_or_vals : [val_or_vals]
  end

  # We store each set of Result entities as a pair: a Finder id together with the strings it finds
  def self.load str
    return Results.new if str.blank?
    hwia = YAML.load str
    results = self.new
    hwia.each do |key, result_vals|
      results[key] = result_vals.map { |result_val| Result.load result_val }
    end
    results
  end

  def self.dump source
    product = Results.new
    source.each do |key, vals|
      product[key] = vals.map { |result| Result.dump result }
    end
    YAML.dump product # Coders::YAMLColumn.new('HashWithIndifferentAccess').dump results # results.to_yaml
  end

end
