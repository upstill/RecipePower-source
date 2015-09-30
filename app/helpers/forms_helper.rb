module FormsHelper

  # Declare a form which submits a JSON request, where the return is processed by RP.submit
  def triggered_form( query, form_id= nil, &block )
    render "shared/triggered_form", form_id: form_id, query: query, contents: with_output_buffer(&block)
  end

end