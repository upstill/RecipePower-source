# Support for ResultsCache classes which filter by result_type and (possibly) subtype
# Includes translation between human-friendly strings and model names
module ResultTyping
  extend ActiveSupport::Concern

  included do
    def self.params_needed
      # The access parameter filters for private and public lists
      (super + [:result_type]).uniq
    end
  end

  def stream_id
    ((uid = defined?(super) && super) ? "#{uid}-" : '') + result_type.stream_id
  end

  # Default itemscope by result_type is to just search the model table
  def itemscope
    @itemscope ||= result_type.model_class.unscoped
  end

end
