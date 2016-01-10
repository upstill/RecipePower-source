{
  replacements: [
      ["div.notification.#{dom_id @notification}"]
  ],
  followup: ({ request: action_path } if defined?(action_path))
}.compact.to_json