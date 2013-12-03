module FeedbackHelper
  def feedback_init(options = {})
    link_to_modal "", new_feedback_path, class: %Q{feedback_link #{options["position"]}}, id: "feedback_link"
    # javascript_tag "$(document).ready(function() { $('.feedback_link').feedback({tabPosition: #{options["position"]}}); });"
  end

  def feedback_tab(options = {})
    feedback_init({'position' => 'left'}.merge(options.stringify_keys))
  end

  def feedback_link(text, options = {})
    link_to_modal text, new_feedback_path, :class => "feedback_link"
  end
end
