module FormsHelper

  # Declare a form which submits a JSON request, where the return is processed by RP.submit
  def triggered_form( query, form_id= nil, &block )
    render "shared/triggered_form", form_id: form_id, query: query, contents: with_output_buffer(&block)
  end

  # Override of form_for which adds options to make RP.submit happy
  def submit_form_for resource, options=nil, &block
    form_for resource, merge_submit_options(options) do |f| block.call f end
  end

  # Override of simple_form_for which asserts options to make RP.submit happy
  def simple_submit_form_for resource, options=nil, &block
    options = merge_submit_options options
    options[:html][:data] = (options[:html][:data] || {}).merge options.delete(:data)
    options[:html][:remote] = options.delete :remote
    simple_form_for resource, options do |f| block.call f end
  end

private
  # Define options for RP.submit to function properly
  def merge_submit_options options
    options = options ? options.deep_dup : {}
    (options[:data] ||= {})[:type] = 'json'
    (options[:html] ||= {})[:onload] = 'RP.submit.form_onload(event);'
    options[:html].delete 'data-type'
    options[:remote] = true
    options
  end

end
