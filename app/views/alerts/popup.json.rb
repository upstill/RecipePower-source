{
    dlog: with_format("html") { render "alerts/popup_#{response_service.injector? ? :injector : :modal}" }
}.to_json