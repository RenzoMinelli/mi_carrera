server "52.90.254.58", user: "deploy", roles: %w{app db web}

set :rails_env, 'production'
set :rvm_custom_path, '/usr/share/rvm'
