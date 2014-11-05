{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
       [ 'div.pagelet-body', ("<div class='pagelet-body'>"+render_template(response_service.controller, response_service.action)+"</div>").html_safe ]
    ]
}.to_json
