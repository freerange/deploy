require 'right_aws'

Capistrano::Configuration.instance(:must_exist).load do
  def provision_role(name, options = {})
    role(name) { provisioned_servers_for_role(name).collect {|s| s[:ip_address]} }
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

  def ec2
    @ec2_credentials ||= YAML.load_file(File.expand_path("~/.ec2/freerange.yml"))
    @ec2 ||= RightAws::Ec2.new(@ec2_credentials["key"], @ec2_credentials["secret_key"])
  end

  namespace :aws do
    task :commission do
      provisioned_roles.each do |name, options|
        ensure_security_group_exists(security_group_for_role(name))        #
        ec2.launch_instances('ami-b91a30cd',
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
  end
end