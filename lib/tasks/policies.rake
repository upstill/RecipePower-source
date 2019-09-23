namespace :policies do
  def actions_for_controller(controller_path)
    route_defaults = Rails.application.routes.routes.map(&:defaults)
    route_defaults = route_defaults.select { |x| x[:controller] == controller_path }
    route_defaults.map { |x| x[:action] }.uniq
  end

  # desc "TODO"

  # Define a policy for controller actions that don't currently have one
  # Any command-line arguments are interpreted as specific controllers to address,
  # expressed as a controller name
  task define: :environment do
    targets = ARGV[1..-1]
    puts "Targetting #{targets}" if targets.present?
    routes = {}
    crud_methods = %w{ index show create new update edit destroy }
    Rails.application.routes.routes.map(&:defaults).each { |route|
      controller, action = route[:controller], route[:action]
      next unless controller.present? && action.present? && !route[:internal]
      next if targets.present? && !targets.include?(controller)
      # puts "Found action '#{action}' on controller '#{controller}'"
      routes[controller] ||= []
      routes[controller] << action unless routes[controller].include?(action)
    }
    # puts "------------- controllers:"
    routes.keys.sort.each { |key|
      file = key.singularize
      # if File.exists?(Rails.root.join("app", "models", "#{file}.rb"))
      unless file.match('/') # No directories please
        non_crud = []
        crud = []
        routes[key].each { |route|
          if crud_methods.include? route
            crud << route
          else
            non_crud << route
          end
        }
        crud_report = (" [ + #{crud.join(', ')}]" if crud.present?)
        # puts "#{key}: #{non_crud.join(', ')}#{crud_report}\n\n"

        model_name = key.singularize.camelize
        policy_name = model_name + 'Policy'
        policy_class = policy_name.constantize rescue nil
        policy_filename = key.singularize + '_policy.rb'
        policy_filepath = Rails.root.join 'app', 'policies', policy_filename
        actions_needed = crud + non_crud
        head = tail = "\n"
        if policy_class
          # Policy already exists: assert only new methods
          actions_needed.keep_if { |action| !policy_class.instance_methods(false).include?(:"#{action}?")}
        else
          head = "class #{policy_name} < ApplicationPolicy\n\n"
          tail = 'end'
        end
        if actions_needed.present?
          puts "Writing policies for #{key}: #{actions_needed.join(', ')}"
          body = actions_needed.map { |action|
            method_body = crud.include?(action) ? 'super' : 'true'
            "  def #{action}?\n    #{method_body}\n  end\n\n"
          }.join
          File.open(policy_filepath, 'a') { |file|
            file.puts head
            file.puts body
            file.puts tail
          }
        else
          puts "No new policies for #{key}"
        end
      end
    }
  end
end
