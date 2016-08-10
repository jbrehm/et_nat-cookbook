nat_instances = search(:node,
                       "#{node['nat']['search_string']} AND" \
                       "chef_environment:#{node.chef_environment} AND " \
                       "nat_cluster_name:#{node['nat']['cluster_name']}")

if nat_instances.count > 2
  # Only try to set up a heartbeat if we're actually in a cluster
  gem_package 'net-ping'
  gem_package 'unf'
  gem_package 'fog'

  gem_package 'nat-monitor' do
    action :upgrade
    version '4.0.2'
  end

  log 'Other instances found.  Setting up the NAT Monitor.' do
    level :info
  end

  node.set['nat']['yaml']['nodes'] =
    nat_instances.each_with_object({}) do |n, m|
      fail "no ec2 attribute found: #{n.inspect}" unless n['ec2']
      m[n['ec2']['instance_id']] = n['ipaddress']
    end

#  if node['nat']['route_table_id']
#    node.set['nat']['yaml']['route_table_id'] = node['nat']['route_table_id']
#  else
#    if node['nat']['yaml']['aws_access_key_id']
#      conn_opts = {
#        aws_access_key_id: node['nat']['yaml']['aws_access_key_id'],
#        aws_secret_access_key: node['nat']['yaml']['aws_secret_access_key']
#      }
#    else
#      conn_opts = { use_iam_profile: true }
#    end

#    if node['nat']['yaml']['aws_url']
#      conn_opts[:endpoint] = node['nat']['yaml']['aws_url']
#    end
#
#    node.set['nat']['yaml']['route_table_id'] =
#      ::EverTrue::EtNat::Helpers.nat_route_table_id(
#        node.chef_environment,
#        conn_opts
#      )
#  end

  if node['nat']['route_tables']
    node['nat']['route_tables'].each_index do |i|
      
      file "/etc/nat_monitor_#{i}.yml" do
        owner 'root'
        group 'root'
        mode 0644
        content yaml_config(node['nat']['route_tables'][i].to_hash)
        notifies :restart, "service[nat-monitor-#{i}]", :delayed
      end

      poise_service "nat-monitor-#{i}" do
        command "/opt/chef/embedded/bin/ruby /opt/chef/embedded/bin/nat-monitor /etc/nat_monitor_#{i}.yml"
        user 'root'
        action [:enable, :start]
      end

      poise_service_options "nat-monitor-#{i}" do
        template 'nat-monitor.erb'
      end
    end
  end
end
