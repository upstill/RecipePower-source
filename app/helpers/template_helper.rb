module TemplateHelper

  # Provide a link that can be short-circuited by resorting to a template of the class given by classname
  # Relevant options:
  # trigger: true if the link should be fired immediately
  def template_link decorator, template_id, label, styling, options={}
    entity = decorator.object
    if entity.is_a? Templateer
      # Assert a :template datum without disturbing any existing :data options
      options[:template] = { id: template_id, subs: entity.data(options.delete(:attribs)) }
    end
    button_options = styling.slice(:button_size).merge options
    link_to_submit label, polymorphic_path([:tag, decorator.as_base_class], styling: styling), button_options
  end

end
