module ErrorsHelper

# Summarize base errors from a resource transaction
  def express_base_errors resource
    resource.errors[:base].empty? ? "" : resource.errors[:base].map { |msg| content_tag(:p, msg) }.uniq.join
  end

# If no preface is provided, use the generic error context
# NB: preface can be locked out entirely by passing ""
  def express_resource_errors resource, options={}
    base_errors = resource.errors[:base] # express_base_errors(resource)
    unless preface = options[:preface]
      if base_errors.first&.match(/([^:]*):(.*$)/)
        preface, base_errors[0] = $1, $2
      else
        preface = express_error_context resource
      end
    end
    details =
        if attribute = options[:attribute] # If an attribute is specified, report that
          (attribute.to_s.upcase+" "+liststrs(resource.errors[attribute])+".")
        else # Otherwise use the base error, if present, falling back on resource errors
          base_errors&.join('<br>').if_present || resource.errors.full_messages.to_sentence
        end
    preface = "<h3>#{preface}</h3>" unless preface.blank?
    (preface+details).html_safe
  end

end
