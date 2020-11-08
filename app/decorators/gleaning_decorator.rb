class GleaningDecorator < ModelDecorator
  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def summarize how=:puts
    self[:results].each { |key, results|
      (how == :puts) ? puts(key) : logger.debug(key)
      results.each { |result|
        fd = result.finderdata
        summ = "    $('#{fd[:selector]}').#{fd['attribute_name']} yields #{result.out}.".truncate 150
        (how == :puts) ? puts(summ) : logger.debug(summ)
      }
      # summ = "#{key}: #{value}".truncate(100)
    }
    nil
  end

  def title
    result_for 'Title'
  end

end
