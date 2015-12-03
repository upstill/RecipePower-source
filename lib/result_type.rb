
class ResultType < String

  def initialize val
    case val
      when nil
        super ''
      when Hash
        super val[:result_type] || ''
      when Symbol
        super val.to_s
      when Draper::Decorator
        super val.object.class.to_s
      when String
        super
      else
        super val.class.to_s
    end
  end

  def root
    split('.').first || ''
  end

  def subtype
    split('.').last
  end

  def stream_id
    gsub /\./, '-'
  end

  # A convenience method to declare params w/o creating an object
  def self.params type
    type.present? ? { result_type: type } : { }
  end

  def params
    @params ||= self.present? ? { result_type: self } : { }
  end

  def entity_params
    @entity_params ||= self.present? ? { entity_type: self.model_name } : { }
  end

  # Express a user-friendly name string as a class name for purposes of naming a result_type
  def model_name
    root.singularize.camelize if root.present?
  end

  def table_name
    root if root.present?
  end

  def model_class
    if root.present?
      model_name.constantize rescue nil
    end
  end

end
