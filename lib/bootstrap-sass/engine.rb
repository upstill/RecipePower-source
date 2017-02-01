puts (["!!!! Loading #{__FILE__} from #{caller.first} !!!!"] + caller).join("\n  >> ")
puts
module Bootstrap
  module Rails
    class Engine < ::Rails::Engine
      # Rails, will you please look in our vendor? kthx
    end
  end
end
puts "#{__FILE__} finished loading."
puts
