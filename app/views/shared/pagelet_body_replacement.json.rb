{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
       [ 'div.pagelet-body', render_template(response_service.controller, response_service.action) ]
    ]
}.to_json
