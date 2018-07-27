require 'result.rb'

class Results < Hash

  def initialize *labels
    labels.each { |label| self[label] = [] }
  end

  def results_for label
    (self[label] || []).map(&:out).flatten.map(&:strip).map(&:if_present).compact.uniq
  end

  def result_for label
    results_for(label).first
  end

  alias_method :labels, :keys

  def assert_result label, val_or_vals
    # We keep these asserted results in Results with no finderdata
    unless prior = (self[label] ||= []).find { |result| result.finderdata.nil? }
      self[label].unshift (prior = Result.new)
    end
    prior.out = val_or_vals.is_a?(Array) ? val_or_vals : [val_or_vals]
  end

end
