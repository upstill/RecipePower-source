class FeedbackFormGenerator < Rails::Generators::Base
  desc "Installs a feedback form. The default model_name is 'feedback'"
  source_root File.expand_path("../templates", __FILE__)
  argument :model_name, :type => :string, :default => 'feedback'
  class_option :jquery, :type => :boolean, :default => false, :description => "Use JQuery instead of prototype"
  class_option :rspec, :type => :boolean, :default => false, :description => "Use RSpec instead of Test::Unit"

  def add_model
    template 'feedback_model.rb.erb', "app/models/#{model_name}.rb"
  end

  def add_mailer
    template 'feedback_mailer.rb.erb', "app/models/#{model_name}_mailer.rb"
    empty_directory "app/views/#{model_name}_mailer"
    copy_file 'views/feedback_mailer/feedback.html.erb', "app/views/#{model_name}_mailer/feedback.html.erb"
  end

  def add_controller
    template 'feedback_controller.rb.erb', "app/controllers/#{model_name}_controller.rb"
  end

  def add_helper
    template_name = options.jquery ? 'feedback_helper.rb.jquery.erb' : 'feedback_helper.rb.prototype.erb'
    template template_name, "app/helpers/#{model_name}_helper.rb"
  end

  def add_views
    empty_directory "app/views/#{model_name}"
    copy_file 'views/feedback/new.html.erb', "app/views/#{model_name}/new.html.erb"
  end

  def add_routes
    route "resources :#{model_name}, :only => [:new, :create]"
  end

  def add_specs
    if options.rspec?
      # TODO
    else
      template 'feedback_test.rb.erb', "test/unit/#{model_name}_test.rb"
      template 'feedback_mailer_test.rb.erb', "test/unit/#{model_name}_mailer_test.rb"
      template 'feedback_controller_test.rb.erb', "test/functional/#{model_name}_controller_test.rb"
    end
  end

  def add_stylesheet
    empty_directory 'app/assets/stylesheets'
    copy_file 'feedback.css', 'app/assets/stylesheets/feedback.css'
  end

  def add_javascript
    empty_directory 'app/assets/javascripts'
    file_name = options.jquery ? 'jquery.feedback.js' : 'prototype.feedback.js'
    copy_file file_name, "app/assets/javascripts/#{file_name}"
  end

  def add_images
    empty_directory 'public/images/feedback'
    copy_file "images/feedback_tab.png", "app/assets/images/feedback/feedback_tab.png"
    copy_file "images/feedback_tab_h.png", "app/assets/images/feedback/feedback_tab_h.png"
    copy_file "images/closelabel.gif", "app/assets/images/feedback/closelabel.gif"
    copy_file "images/loading.gif", "app/assets/images/feedback/loading.gif"
  end


  private

  def model_class_name
    model_name.classify
  end

  def mailer_class_name
    "#{model_class_name}Mailer"
  end

  def controller_class_name
    "#{model_class_name}Controller"
  end

  def helper_class_name
    "#{model_class_name}Helper"
  end
end
