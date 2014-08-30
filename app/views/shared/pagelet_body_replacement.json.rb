{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        stream_element_replacement(:body) {
          render_template(response_service.controller, response_service.action)
        }
    ]
}.to_json
