set :stages, %w(production)
set :default_stage, "production"

require 'freerange/deploy'

# set :application, "WORLD"
# set :repository,  "TOM"

after "deploy:finalize_update" do
  # The default recipe already runs bundler install and db:migrate
  # but other steps you need to run after the code has been updated
  # (such as generate css) should go here
end