require 'rubygems'
require 'thor'

module FreeRange
  module CLI
    class Deploy < Thor
      include Thor::Actions
      
      def self.source_root
        File.expand_path("../templates", __FILE__)
      end
      
      argument :repository, :required => true, :desc => 'Git repository containing app, e.g. git@github.com:freerange/deploy.git'
      argument :host, :required => true, :desc => 'Hostname to deploy to, e.g api.hashblue.com'
      argument :name, :required => false, :desc => 'Name of app, e.g firehose'
      
      desc 'setup', 'Setup freerange deployment files, eg freerange-deploy setup git@github.com:freerange/o2-firehose.git api.firehose.com firehose'
      def setup
        self.name ||= host
        template 'Capfile.erb', 'Capfile'
        template 'deploy.rb.erb', 'config/deploy.rb'
        template 'staging.rb.erb', 'config/deploy/staging.rb'
        template 'production.rb.erb', 'config/deploy/production.rb'
      end
    end
  end
end