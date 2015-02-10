module FormsHelper

  # Declare a form which submits a JSON request, where the return is processed by RP.submit
  def triggered_form( query, &block )
    render "shared/triggered_form", query: query, contents: with_output_buffer(&block)
  end

end