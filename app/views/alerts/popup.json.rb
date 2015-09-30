method = :dlog unless defined?(method) && method.present?
{
    method => with_format("html") {
      render "alerts/popup_#{response_service.injector? ? :injector : :modal}",
             alert_hdr: defined?(alert_hdr) && alert_hdr
    }
}.to_json