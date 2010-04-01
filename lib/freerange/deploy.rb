require 'capistrano/ext/multistage'

Capistrano::Configuration.instance(:must_exist).load do
  # User details
  set :user,          'deploy'
  set :group,         'admin'

  # Application details
  set(:runner)        { user }
  set :use_sudo,      false

  # SCM settings
  set :scm,           'git'
  set :deploy_via, :remote_cache

  # Deploy to our default location
  set(:deploy_to)   { "/var/www/#{application}" }
  set(:sites)       { }

  # Git settings for Capistrano
  default_run_options[:pty]     = true # needed for git password prompts
  ssh_options[:forward_agent]   = true # use the keys for the person running the cap command to check out the app

  namespace :host do
    task :create do
      vhost_template =<<-EOT
<VirtualHost *:80>
  ServerName #{domain}
  DocumentRoot /var/www/#{application}/current/public
  <Directory "/var/www/#{application}/current/public">
    allow from all
    Options +Indexes
  </Directory>
</VirtualHost>
      EOT
      
      put vhost_template.strip, "/etc/apache2/sites-available/#{domain}"
    end
    
    task :enable do
      run "a2ensite #{domain}"
      sudo "apache2ctl graceful"
    end
    
    task :disable do
      run "a2dissite #{domain}"
      sudo "apache2ctl graceful"
    end
    
    task :setup do
      host.create
      host.enable
    end
  end
  
  # We're using passenger, so start/stop don't apply, while restart needs to just
  # touch path/restart.txt

  namespace :deploy do
    task :start do ; end
    task :stop do ; end
    task :restart, :roles => :app, :except => { :no_release => true } do
      run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
    end

    task :bundle, :roles => :app do
      run "cd #{release_path} && bundle install"
    end
  end

  after "deploy:finalize_update" do
    deploy.bundle
    deploy.migrate
  end
end