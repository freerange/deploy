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
  set(:deploy_to)   { "/var/apps/#{application}" }

  # Git settings for Capistrano
  default_run_options[:pty]     = true # needed for git password prompts
  ssh_options[:forward_agent]   = true # use the keys for the person running the cap command to check out the app

  # This flag can be used to avoid chicken/egg situations such as when stopping queues before a deploy
  set :first_deploy, false

  namespace :deploy do
    desc "Runs deploy:setup and deploy, first the first_deploy flag to true"
    task :first do
      set :first_deploy, true
    end
  end

  after "deploy:first", "deploy:setup"
  after "deploy:first", "deploy"

  def sudo_put(data, target)
    tmp = "#{shared_path}/~tmp-#{rand(9999999)}"
    put data, tmp
    on_rollback { run "rm #{tmp}" }
    sudo "cp -f #{tmp} #{target} && rm #{tmp}"
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
      run "cd #{release_path} && bundle install #{shared_path}/gems"
    end

    task :announce do
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

      message_to_announce = "#{name} #{word} deployed build #{deployed} of #{application} to #{hosts}.  Changes deployed: #{compare_url}"

      if room = fetch('campfire_room', nil)
        require 'tinder'
        require 'json'
        campfire = Tinder::Campfire.new(fetch('campfire_domain', 'gofreerange'))
        campfire.login(fetch('campfire_key'), 'x')
        room = campfire.find_room_by_name(room)
        room.speak message_to_announce
      end

      if deploy_webhook_url = fetch('deploy_webhook_url',nil)
        require 'net/http'
        require 'json'
        data = {
            :deployed_by => name,
            :build => deployed,
            :application => application,
            :compare_url => compare_url,
            :github_url => github_url,
            :hosts => hosts
        }

        Net::HTTP.post_form(URI.parse(deploy_webhook_url),{"payload" => data.to_json})
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
