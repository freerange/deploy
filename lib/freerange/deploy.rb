require 'capistrano/ext/multistage'

Capistrano::Configuration.instance(:must_exist).load do
  # User details
  set :user, 'deploy'
  set :group, 'admin'

  # Application details
  set(:runner)        { user }
  set :use_sudo,      false

  # SCM settings
  set :scm, 'git'
  set :branch, 'master'
  set :deploy_via, :remote_cache

  # Deploy to our default location
  set(:deploy_to)   { "/var/www/#{application}" }
  set(:sites)       { }

  # Git settings for Capistrano
  default_run_options[:pty]     = true # needed for git password prompts
  ssh_options[:forward_agent]   = true # use the keys for the person running the cap command to check out the app

  # This flag can be used to avoid chicken/egg situations such as when stopping queues before a deploy
  set :first_deploy, false

  namespace :deploy do
    desc "Deploys project, setting first_deploy flag to true"
    task :first do
      set :first_deploy, true
    end
  end

  after "deploy:first", "deploy"

  set(:vhost_template) {<<-EOT
<VirtualHost *:80>
ServerName #{domain}
DocumentRoot /var/www/#{application}/current/public
<Directory "/var/www/#{application}/current/public">
allow from all
Options +Indexes
</Directory>
</VirtualHost>
EOT
  }

  namespace :host do
    task :create do
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

  namespace :redis do
    task :setup do
      if fetch('require_redis', nil)
        sudo "apt-get install redis-server"
      end
    end
  end

  after "deploy:setup", "host:setup"
  after "deploy:setup", "redis:setup"

  set :monit_processes, []

  def monit_process(name, directives)
    monit_processes << "check process #{name}#{directives}"
  end

  def combined_monit_config
    base = %{
set daemon  120
  with start delay 240
set logfile syslog facility log_daemon
set mailserver localhost
set mail-format { from: #{monit_email} }
set alert #{monit_email}
set httpd port 2812 and
  allow deploy:fr33r4n63
check system localhost
  if loadavg (1min) > 4 then alert
  if loadavg (5min) > 2 then alert
  if memory usage > 75% then alert
  if cpu usage (user) > 70% then alert
  if cpu usage (system) > 30% then alert
  if cpu usage (wait) > 20% then alert}

    apache = %{
check process apache2 with pidfile /var/run/apache2.pid
  start program = "/usr/sbin/apache2ctl start"
  stop  program = "/usr/sbin/apache2ctl stop"
  if cpu > 60% for 2 cycles then alert
  if cpu > 80% for 5 cycles then restart
  if children > 200 then restart
  if loadavg(5min) greater than 10 for 8 cycles then restart}

    ([base, apache] + monit_processes).join("\n")
  end

  def sudo_put(data, target)
    tmp = "#{shared_path}/~tmp-#{rand(9999999)}"
    put data, tmp
    on_rollback { run "rm #{tmp}" }
    sudo "cp -f #{tmp} #{target} && rm #{tmp}"
  end

  namespace :monit do
    task :setup do
      if monit_processes.any?
        sudo "apt-get install monit"
        sudo_put combined_monit_config, "/etc/monit/monitrc"
        sudo_put "startup=1", "/etc/default/monit"
        sudo "/etc/init.d/monit restart"
      end
    end
  end

  after "deploy:setup", "monit:setup"

  # We're using passenger, so start/stop don't apply, while restart needs to just
  # touch path/restart.txt

  namespace :deploy do
    task :start do ; end
    task :stop do ; end
    task :restart, :roles => :app, :except => { :no_release => true } do
      run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
    end

    task :bundle, :roles => :app do
      run "cd #{release_path} && bundle install #{shared_path}/gems"
    end

    task :announce do
      if room = fetch('campfire_room', nil)
        require 'tinder'
        require 'json'
        campfire = Tinder::Campfire.new(fetch('campfire_domain', 'gofreerange'))
        campfire.login(fetch('campfire_key'), 'x')
        room = campfire.find_room_by_name(room)

        name = `git config --get user.name`.strip

        source_repo_url = repository
        deploying = `git rev-parse HEAD`[0,7]
        begin
          deployed = previous_revision[0,7]
        rescue
          deployed = "000000"
        end

        github_url = repository.gsub(/git@/, 'http://').gsub(/\.com:/,'.com/').gsub(/\.git/, '')
        compare_url = "#{github_url}/compare/#{deployed}...#{deploying}"

        hosts = roles[:app].collect{|r| r.host }.join(", ")

        word = name =~ /&/ ? 'have' : 'has'
        room.speak "#{name} #{word} deployed build #{deployed} of #{application} to #{hosts}.  Changes deployed: #{compare_url}"
      end
    end
  end

  after "deploy:finalize_update" do
    deploy.bundle
    deploy.migrate
  end

  after "deploy" do
    deploy.announce
  end

  desc "Tail server log files (deprecated, use log:tail instead)"
  task :tail, :roles => :app do

  end

  desc "Print the version of the currently deployed application"
  task :version do
    puts "Current version deployed to #{stage} is: #{current_revision}"
  end

  desc "Use github to view which commits have been deployed to staging, but not to production"
  task :staged_changes do
    staging = `cap staging version`.split(": ").last.slice(0,8)
    production = `cap production version`.split(": ").last.slice(0,8)
    repo = repository.split(":").last.gsub(".git", "")
    `open "https://github.com/#{repo}/compare/#{production}...#{staging}"`
  end
end