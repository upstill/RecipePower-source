class GleaningDecorator < ModelDecorator
  include Templateer
  include DialogPanes
  delegate_all

  # Provide a list of the editing panes available for the object
  def dialog_pane_list topics=nil # A comma-separated list of topics to edit
    Pundit.policy(User.current, object.site).edit? ? [dialog_pane_spec( :site)] : []
  end

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

  # Regenerate content when the site finders for Content have changed
  def regenerate_dependent_content
    # The page_ref will produce different output if the site's trimmers have changed
    refresh_attributes :content if changed_for_autosave? # site.finders_for('Content').any? { |f| f.changed? }
  end

end
