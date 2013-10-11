module FeedbackHelper
  def feedback_init(options = {})
    options = {
      "position" => "null"
    }.merge(options.stringify_keys)

    options['position'] = "'#{options['position']}'" unless options['position'].blank? || options['position'] == 'null'
    javascript_tag "$(document).ready(function() { $('.feedback_link').feedback({tabPosition: #{options["position"]}}); });"
  end

  def feedback_tab(options = {})
    feedback_init({'position' => 'top'}.merge(options.stringify_keys))
  end

  def feedback_link(text, options = {})
    link_to_modal text, new_feedback_path, :class => "feedback_link"
  end
end
