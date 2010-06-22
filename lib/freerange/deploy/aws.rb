require 'right_aws'

Capistrano::Configuration.instance(:must_exist).load do
  RAW_AMIS = {
    "lucid-32" => "ami-cf4d67bb",
    "lucid-64" => "ami-a54d67d1"
  }

  def provision_role(name, options = {})
    role(:app) { provisioned_servers_for_role(:app).collect {|s| s[:ip_address]} }
    role(:web) { provisioned_servers_for_role(:web).collect {|s| s[:ip_address]} }
    
    provisioned_roles[name] = options
  end

  def provisioned_roles
    @provisioned_roles ||= {}
  end

  def provisioned_servers_for_role(name)
    servers = ec2.describe_instances
    servers_in_role = servers.select do |s|
      s[:aws_state] == "running" && s[:aws_groups].include?(security_group_for_role(name))
    end
  end

  def security_group_for_role(name)
    "#{fetch("application")}-#{fetch("stage")}-#{name}"
  end

  def ensure_security_group_exists(name)
    group_names = ec2.describe_security_groups.collect {|g| g[:aws_group_name]}
    unless group_names.include?(name)
      ec2.create_security_group(name, name)
    end
  end

  def wait_for_instances_to_start(*instances)
    Kernel.print "Waiting for instances #{instances.join(", ")} to start.."
    servers = ec2.describe_instances(*instances)
    while servers.detect {|s| s[:aws_state] == "pending"}
      Kernel.print '.'
      sleep 2
      servers = ec2.describe_instances(*instances)
    end
    Kernel.print "\n"
    # Even though the instance is marked as running, it doesn't seem to respond immediately
    # so let's wait another 20 seconds to give it a time to spark into life
    sleep 20
    servers
  end

  def ec2_options
    @ec2_options ||= YAML.load_file(File.expand_path("~/.ec2/freerange.yml"))
  end

  def ec2
    @ec2 ||= RightAws::Ec2.new(ec2_options["key"], ec2_options["secret_key"])
  end

  def bundle_image(host, bundle_name)
    put File.read(File.expand_path(ec2_options["pk"])), "/tmp/pk.pem", :hosts => [host]
    put File.read(File.expand_path(ec2_options["cert"])), "/tmp/cert.pem", :hosts => [host]
    sudo "mv /tmp/*.pem /mnt", :hosts => [host]
    bundle_script = %{
      if [ $(uname -m) = 'x86_64' ]; then
        arch=x86_64
      else
        arch=i386
      fi

      prefix="#{bundle_name}"

      sudo apt-get install -y ec2-ami-tools
      sudo apt-get install -y ec2-api-tools

      sudo -E ec2-bundle-vol -r $arch -d /mnt -p $prefix -u #{ec2_options["user_id"]} -k /mnt/pk.pem -c /mnt/cert.pem -s 10240 -e /mnt,/root/.ssh,/home/ubuntu/.ssh

      ec2-upload-bundle -b freerange-ec2-images -m /mnt/$prefix.manifest.xml -a #{ec2_options["key"]} -s #{ec2_options["secret_key"]}

      ec2-register -K /mnt/pk.pem -C /mnt/cert.pem --region eu-west-1 --name "freerange-ec2-images/$prefix" "freerange-ec2-images/$prefix.manifest.xml"

      sudo rm -rf /mnt/*.pem
      sudo rm -rf /mnt/$prefix.*
    }
    put bundle_script, "/tmp/make-bundle", :hosts => [host]
    run "chmod +x /tmp/make-bundle", :hosts => [host]
    run "/tmp/make-bundle", :hosts => [host]
  end

  namespace :aws do
    task :commission do
      provisioned_roles.each do |name, options|
        ensure_security_group_exists(security_group_for_role(name))        #
        ec2.launch_instances('ami-931d37e7',
          :min_count => options[:servers],
          :instance_type => options[:type],
          :group_ids => ['default', security_group_for_role(name)]
        )
      end
    end

    task :decommission do
      provisioned_roles.each do |name, options|
        instances = provisioned_servers_for_role(name).collect {|s| s[:aws_instance_id]}
        ec2.terminate_instances instances
      end
    end

    task :build_bootstrap_images do
      lucid_32 = ec2.launch_instances('ami-cf4d67bb', :min_count => 1, :instance_type => 'm1.small', :key_name => 'freerange').first[:aws_instance_id]
      lucid_64 = ec2.launch_instances('ami-a54d67d1', :min_count => 1, :instance_type => 'm1.large', :key_name => 'freerange').first[:aws_instance_id]

      servers = wait_for_instances_to_start(lucid_32, lucid_64)
      hosts = servers.collect {|s| s[:dns_name]}

      set :user, "ubuntu"
      run "sudo env", :hosts => hosts
      run "wget -q -O - http://github.com/freerange/freerange-puppet/raw/master/bootstrap.sh | sudo sh", :hosts => hosts
      bundle_image hosts.first, "ubuntu-lucid-32-bootstrap"
      ec2.terminate_instances lucid_32
      bundle_image hosts.last, "ubuntu-lucid-64-bootstrap"
      ec2.terminate_instances lucid_64
    end

    task :build_application_images do
      images = ec2.ec2_describe_images({'Owner' => ['self']})
      require 'pp'
      pp images
      lucid_32_image = images.detect {|i| i[:name].split("/").last == "ubuntu-lucid-32-bootstrap"}
      lucid_32_instances = ec2.launch_instances(lucid_32_image[:aws_id], :min_count => roles.size, :instance_type => 'm1.small', :key_name => 'freerange').collect {|i| i[:aws_instance_id]}
      servers = wait_for_instances_to_start(*lucid_32_instances)
      hosts = servers.collect {|s| s[:dns_name]}
      hosts_and_roles = hosts.zip(roles.keys)
            
      sudo "mkdir -p /etc/puppet/manifests/apps", :hosts => hosts
      
      hosts_and_roles.each do |host, role|
        put ERB.new(puppet_manifests[role]).result(binding), "/home/freerange/#{application}.#{role}.pp", :hosts => host
        sudo "mv /home/freerange/#{application}.#{role}.pp /etc/puppet/manifests/apps/#{application}.#{role}.pp", :hosts => host
      end

      sudo "puppet -v -d /etc/puppet/manifests/site.pp", :hosts => hosts
      
      hosts_and_roles.each do |host, role|
        bundle_image host, "ubuntu-lucid-32-#{application}-#{role}"
      end
      
      ec2.terminate_instances lucid_32_instances
    end
  end
end