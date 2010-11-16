require 'tinder'
require 'json'

module Hub
  # Provides methods for inspecting the environment, such as GitHub user/token
  # settings, repository info, and similar.
  module Context
    # Caches output when shelling out to git
    GIT_CONFIG = Hash.new do |cache, cmd|
      result = %x{git #{cmd}}.chomp
      cache[cmd] = $?.success? && !result.empty? ? result : nil
    end

    # Parses URLs for git remotes and stores info
    REMOTES = Hash.new do |cache, remote|
      if remote
        url = GIT_CONFIG["config remote.#{remote}.url"]

        if url && url.to_s =~ %r{\bgithub\.com[:/](.+)/(.+).git$}
          cache[remote] = { :user => $1, :repo => $2 }
        else
          cache[remote] = { }
        end
      else
        cache[remote] = { }
      end
    end

    LGHCONF = "http://github.com/guides/local-github-config"

    def repo_owner
      REMOTES[default_remote][:user]
    end

    def repo_user
      REMOTES[current_remote][:user]
    end

    def repo_name
      REMOTES[default_remote][:repo] || File.basename(Dir.pwd)
    end

    # Either returns the GitHub user as set by git-config(1) or aborts
    # with an error message.
    def github_user(fatal = true)
      if user = GIT_CONFIG['config github.user']
        user
      elsif fatal
        abort("** No GitHub user set. See #{LGHCONF}")
      end
    end

    def github_token(fatal = true)
      if token = GIT_CONFIG['config github.token']
        token
      elsif fatal
        abort("** No GitHub token set. See #{LGHCONF}")
      end
    end

    def current_branch
      GIT_CONFIG['symbolic-ref -q HEAD']
    end

    def tracked_branch
      branch = current_branch && tracked_for(current_branch)
      normalize_branch(branch) if branch
    end

    def remotes
      list = GIT_CONFIG['remote'].to_s.split("\n")
      main = list.delete('origin') and list.unshift(main)
      list
    end

    def remotes_group(name)
      GIT_CONFIG["config remotes.#{name}"]
    end

    def current_remote
      return if remotes.empty?

      if current_branch
        remote_for(current_branch)
      else
        default_remote
      end
    end

    def default_remote
      remotes.first
    end

    def normalize_branch(branch)
      branch.sub('refs/heads/', '')
    end

    def remote_for(branch)
      GIT_CONFIG['config branch.%s.remote' % normalize_branch(branch)]
    end

    def tracked_for(branch)
      GIT_CONFIG['config branch.%s.merge' % normalize_branch(branch)]
    end

    def http_clone?
      GIT_CONFIG['config --bool hub.http-clone'] == 'true'
    end

    # Core.repositoryformatversion should exist for all git
    # repositories, and be blank for all non-git repositories. If
    # there's a better config setting to check here, this can be
    # changed without breaking anything.
    def is_repo?
      GIT_CONFIG['config core.repositoryformatversion']
    end

    def github_url(options = {})
      repo = options[:repo]
      user, repo = repo.split('/') if repo && repo.index('/')
      user ||= options[:user] || github_user
      repo ||= repo_name
      secure = options[:private]

      if options[:web] == 'wiki'
        scheme = secure ? 'https:' : 'http:'
        '%s//wiki.github.com/%s/%s/' % [scheme, user, repo]
      elsif options[:web]
        scheme = secure ? 'https:' : 'http:'
        path = options[:web] == true ? '' : options[:web].to_s
        '%s//github.com/%s/%s%s' % [scheme, user, repo, path]
      else
        if secure
          url = 'git@github.com:%s/%s.git'
        elsif http_clone?
          url = 'http://github.com/%s/%s.git'
        else
          url = 'git://github.com/%s/%s.git'
        end

        url % [user, repo]
      end
    end
  end
end

def campfire_room
  @room ||= begin
    unless defined?(CAMPFIRE_DOMAIN) && defined?(CAMPFIRE_ROOM) && defined?(CAMPFIRE_KEY)
      raise "You must define CAMPFIRE_DOMAIN, CAMPFIRE_ROOM and CAMPFIRE_KEY to get build notifications to work"
    end
    campfire = Tinder::Campfire.new(CAMPFIRE_DOMAIN, :ssl => true)
    campfire.login(CAMPFIRE_KEY, 'x')
    campfire.find_room_by_name(CAMPFIRE_ROOM)
  end
end

extend Hub::Context

namespace :build do
  require 'net/http'
  require 'freerange/webhook'
  namespace :announce do
    task :failure do
      revision = `git rev-parse HEAD`.gsub("\n", '')
      message = "Build #{revision} of #{repo_name} failed: #{github_url(:web => true, :user => 'freerange')}/commits/#{revision}"
      build_output = File.read(".build/output")

      if defined?(BUILD_WEBHOOK_URL)
        data = {
          :message => message,
          :result => "failure",
          :build_output => build_output,
          :repo_name => repo_name,
          :revision => revision
        }
        Freerange::Webhook.post(BUILD_WEBHOOK_URL, data)
      end

      if defined?(CAMPFIRE_DOMAIN)
        campfire_room.speak(message)
        campfire_room.speak(build_output)
      end
    end

    task :success do
      revision = `git rev-parse HEAD`.gsub("\n", '')
      message = "Build #{revision} of #{repo_name} was a great success!"

      if defined?(BUILD_WEBHOOK_URL)
        data = {
          :message => message,
          :result => "success",
          :repo_name => repo_name,
          :revision => revision
        }
        Freerange::Webhook.post(BUILD_WEBHOOK_URL, data)
      end

      if defined?(CAMPFIRE_ANNOUNCE)
        campfire_room.speak(message)
      end
    end
  end
end
