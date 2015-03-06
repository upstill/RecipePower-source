module ErrorsHelper

# Summarize base errors from a resource transaction
  def express_base_errors resource
    resource.errors[:base].empty? ? "" : resource.errors[:base].map { |msg| content_tag(:p, msg) }.join
  end

# If no preface is provided, use the generic error context
# NB: preface can be locked out entirely by passing ""
  def express_resource_errors resource, options={}
    preface = options[:preface] || express_error_context(resource)
    base_errors = options[:with_base] ? express_base_errors(resource) : ""
    details =
        if attribute = options[:attribute]
          (attribute.to_s.upcase+" "+enumerate_strs(resource.errors[attribute])+".")
        else
          resource.errors.full_messages.to_sentence
        end + base_errors
    preface = "<strong>#{preface}</strong>: " unless preface.blank?
    preface+details
  end

end
