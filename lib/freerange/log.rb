Capistrano::Configuration.instance(:must_exist).load do
  set(:log_path)         {"#{shared_path}/log/#{stage}.log"}

  namespace :log do
    desc "Tail server log files"
    task :tail, :roles => :app do
      trap("INT") { exit(0) }
      puts
      puts "Checking server time"
      run "date"
      puts
      run "tail -f #{log_path}" do |channel, stream, data|
        puts  # for an extra line break before the host name
        puts "#{channel[:host]}: #{data}"
        break if stream == :err
      end
    end

    task :download, :roles => :app do
      top.download log_path, "log/$CAPISTRANO:HOST$.remote-#{stage}.log", :via => :scp
    end

    namespace :analyze do
      task :recent, :roles => :app do
        run "tail -50000 #{log_path} > #{shared_path}/log/#{stage}.log-tail"
        top.download "#{shared_path}/log/#{stage}.log-tail", "log/$CAPISTRANO:HOST$.remote-#{stage}.log-tail", :via => :scp
        system "bundle exec request-log-analyzer log/*.remote-#{stage}.log-tail"

        puts %{
To do further analysis, use the log:download task, then run request-log-analyzer independently, e.g:

  bundle exec request-log-analyzer log/*.remote-#{stage}.log
  bundle exec request-log-analyzer log/*.remote-#{stage}.log --before 2010-08-01
        }
      end
    end
  end
end