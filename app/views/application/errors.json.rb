# flash_notify((entity if defined? entity), !response_service.injector?).to_json
# Present flash errors on an entity to the user, either as a popup or a flash
flash_notify((entity if defined? entity),
             defined?(with_popup) ? with_popup : !response_service.injector?).to_json