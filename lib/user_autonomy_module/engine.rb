# frozen_string_literal: true
module ::UserAutonomyModule
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace UserAutonomyModule
    config.autoload_paths << File.join(config.root, "lib")
  end
end
