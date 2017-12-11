# This hook file is located at '/etc/chef/chefctl_hooks.rb'
# You can change this location by passing `-p/--plugin-path` to `chefctl`,
# or by setting `plugin_path` in `chefctl-config.rb`

# This hook will update cookbook repos from source control and generate a stub
# `client.rb` for Chef if needed.
module RepoHook
  class Repo
    def initialize(name, data)
      @name = name
      @url = data['url']
      if data['type']
        @type = data['type']
      elsif data['url'].include?('git')
        @type = 'git'
      else
        @type = 'hg'
      end
      if data['path']
        @path = data['path']
      else
        @path = File.join(Chefctl::Config.repos_path, name)
      end

      if data['ssh_key']
        @ssh_key = data['ssh_key']
      end
    end

    attr_reader :name, :path, :ssh_key, :type, :url

    def update
      sshopts = ''
      sshenv = {}
      if @ssh_key
        sshcmd = "ssh -i #{@ssh_key}"
        sshopts = "-e '#{sshcmd}'"
        sshenv['GIT_SSH'] = sshcmd
      end
      if File.directory?(@path)
        case @type
        when 'git'
          cmd = Mixlib::ShellOut.new('git pull',
                                     :cwd => @path,
                                     :environment => sshenv)
          cmd.run_command
          cmd.error!
        when 'hg'
          cmd = Mixlib::ShellOut.new("hg pull #{sshopts} -u",
                                     :cwd => @path)
          cmd.run_command
          cmd.error!
        else
          puts "Unsupported repo type: #{@type}"
          exit 1
        end
      else
        case @type
        when 'git'
          cmd = Mixlib::ShellOut.new("git clone #{@url} #{@path}",
                                     :environment => sshenv)
          cmd.run_command
          cmd.error!
        when 'hg'
          cmd = Mixlib::ShellOut.new(
            "hg clone #{sshopts} #{@url} #{@path}",
          )
          cmd.run_command
          cmd.error!
        else
          puts "Unsupported repo type: #{@type}"
          exit 1
        end
      end
    end
  end

  def pre_start
    {
      'chef_config_path' => '/etc/chef',
      'repos_path' => '/var/chef/repos',
      'ssh_keys_path' => '/var/chef/keys',
      'file_backup_path' => '/var/chef/backup',
      'file_cache_path' => '/var/chef/cache',
      'node_path' => '/var/chef/nodes',

      # These defaults are mostly meant for CI and testing
      'runlist' => 'recipe[fb_init_sample]',
      'repos' => {
        'chef-cookbooks' => {
          'url' => 'https://github.com/davide125/chef-cookbooks.git',
        },
      },
    }.each do |key, val|
      unless Chefctl::Config[key]
        Chefctl::Config[key] = val
      end
    end

    Chefctl::Config.chef_options <<
      "-j #{Chefctl::Config.chef_config_path}/run-list.json"
  end

  def pre_run(_output)
    unless File.exists?(Chefctl::Config.repos_path)
      FileUtils.mkdir_p(Chefctl::Config.repos_path, :mode => 0o775)
    end

    Chefctl::Config.repos.each do |name, data|
      repo = Repo.new(name, data)
      Chefctl.logger.info("Updating #{repo.name}")
      repo.update
    end

    client_rb = "#{Chefctl::Config.chef_config_path}/client.rb"
    unless File.exists?(client_rb)
      Chefctl.logger.info("Generating #{client_rb}")

      cookbook_paths = []
      role_path = nil

      Chefctl::Config.repos.each do |name, data|
        repo = Repo.new(name, data)
        if File.directory?("#{repo.path}/cookbooks")
          cookbook_paths << "#{repo.path}/cookbooks"
        end
        if File.directory?("#{repo.path}/roles")
          role_path = "#{repo.path}/roles"
        end
      end

      if cookbook_paths
        client_rb_lines = [
          "cookbook_path #{cookbook_paths}",
          "file_backup_path '#{Chefctl::Config.file_backup_path}'",
          "file_cache_path '#{Chefctl::Config.file_cache_path}'",
          "node_path '#{Chefctl::Config.node_path}'",
          'local_mode true',
        ]
        if role_path
          client_rb_lines << "role_path '#{role_path}'"
        end
        File.open(client_rb, 'w', 0644) do |f|
          f.write(client_rb_lines.join("\n"))
        end
      end
    end

    runlist_json = "#{Chefctl::Config.chef_config_path}/run-list.json"
    unless File.exists?(runlist_json)
      File.open(runlist_json, 'w', 0644) do |f|
        f.write("{\"run_list\":[\"#{Chefctl::Config.runlist}\"]}")
      end
    end
  end
end

Chefctl::Plugin.register RepoHook
