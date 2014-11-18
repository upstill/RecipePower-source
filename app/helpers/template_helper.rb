module TemplateHelper

  # Provide a link that can be short-circuited by resorting to a template of the class given by classname
  # Relevant options:
  # trigger: true if the link should be fired immediately
  def template_link entity, classname, label, options={}
    if entity.is_a? Templateer
      options = options.merge template: true, data: { template_id: classname, template_data: entity.data }
    end
    link_to_submit label, polymorphic_path(entity)+"/edit", options
  end

end