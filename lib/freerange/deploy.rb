require "git_deploy"

Capistrano::Configuration.instance(:must_exist).load do
  # User details
  set :user,          'deploy'
  set :group,         'admin'

  # Application details
  set(:runner)        { user }
  set :use_sudo,      false

  # SCM settings
  set :scm,           'git'
  # set to the name of git remote you intend to deploy to
  set :remote,        'production' # overrides the default git-deploy setting of 'origin'
  # specify the deployment branch
  set :branch,        'master'

  # The appliation name defaults to the name of the repository at the origin remote
  set(:application) { File.basename(`#{source.local.scm('config', "remote.origin.url")}`, ".git") }
  
  # Deploy to our default location
  set(:deploy_to)   { "/var/www/#{application}" }

  # Git settings for Capistrano
  default_run_options[:pty]     = true # needed for git password prompts
  ssh_options[:forward_agent]   = true # use the keys for the person running the cap command to check out the app


  before "deploy:setup", "freerange:setup_git_remote"
  after "deploy:setup", "freerange:setup_apache"

  namespace "freerange" do
    task :setup_git_remote do
      remote_url = "deploy@#{roles[:app].first}:/var/www/#{application}"
      puts "Setting up git remote '#{remote}' -> #{remote_url}"
      `git remote add #{remote} #{remote_url}`
    end
    task :setup_apache do
      vhost_template =<<-EOT
<VirtualHost *>
  DocumentRoot /var/www/#{application}/public
  ServerName #{application}
  <Directory "/var/www/#{application}/public">
    allow from all
    Options +Indexes
    </Directory>
</VirtualHost>
      EOT

      put vhost_template.strip, "/var/www/apache_vhosts/#{application}"
      
      # Disable the default site, just in case; it will get in the way.
      sudo "a2dissite default"
      
      # Restart apache
      sudo "apache2ctl restart"
    end
  end
end