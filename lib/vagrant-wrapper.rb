#
# Author:: BinaryBabel OSS (<projects@binarybabel.org>)
# Homepage:: http://www.binarybabel.org
# License:: MIT
#
# For bugs, docs, updates:
#
#     http://code.binbab.org
#
# Copyright 2013 sha1(OWNER) = df334a7237f10846a0ca302bd323e35ee1463931
#
# See LICENSE file for more details.
#

require 'vagrant-wrapper/exceptions'
require 'shellwords'

# Main class for the VagrantWrapper driver.
# This driver will search predefined paths for a packaged version of Vagrant,
# followed by the system's environment PATH. Ideal functionality being that
# a stale Gem version of Vagrant will be overriden by the packaged version
# if the vagrant-wrapper Gem is required in your bundle.
class VagrantWrapper

  def initialize(*args)
    @vagrant_name = "vagrant"
    @vagrant_path = nil
    @search_paths = default_paths + env_paths
    @wrapper_mark = "END VAGRANT WRAPPER"

    # Optional first parameter sets required version.
    unless args.length < 1 or args[0].nil?
      require_version args[0]
    end
  end

  # Require a specific version (or range of versions).
  # Ex. ">= 1.1"
  def require_version(version)
    version_req = Gem::Requirement.new(version)
    vagrant_ver = vagrant_version
    raise Exceptions::NotInstalled, "Vagrant is not installed." if vagrant_ver.nil?
    unless version_req.satisfied_by?(Gem::Version.new(vagrant_ver))
      raise Exceptions::Version, "Vagrant #{version} is required. You have #{vagrant_ver}."
    end
  end

  # Call the discovered version of Vagrant.
  # The given arguments (if any) are passed along to the command line.
  #
  # The output will be returned.
  def get_output(*args)
    if args.length > 0 && args[0].is_a?(Array)
      send("call_vagrant", *args[0])
    else
      send("call_vagrant", *args)
    end
  end

  # Execute the discovered version of Vagrant.
  # The given arguments (if any) are passed along to the command line.
  #
  # The vagrant process will replace this process entirely, operating
  # and outputting in an unmodified state.
  def execute(*args)
    if args.length > 0 && args[0].is_a?(Array)
      send("exec_vagrant", *args[0])
    else
      send("exec_vagrant", *args)
    end
  end
  
  # Return the filesystem location of the discovered Vagrant install.
  def vagrant_location
    find_vagrant
  end
  
  # Return the version of the discovered Vagrant install.
  def vagrant_version
    ver = call_vagrant "-v"
    unless ver.nil?
      ver = ver[/(\.?[0-9]+)+/]
    end
    ver
  end

  # Default paths to search for the packaged version of Vagrant.
  #   /opt/vagrant/bin
  #   /usr/local/bin
  #   /usr/bin
  #   /bin
  def default_paths
    %w{
      /opt/vagrant/bin
      /usr/local/bin
      /usr/bin
      /bin
    }
  end

  # Environment search paths to be used as low priority search.
  def env_paths
    path = ENV['PATH'].to_s.strip
    return [] if path.empty?
    path.split(':')
  end

  def self.install_instructions
    "See http://www.vagrantup.com for instructions.\n"
  end

  def self.require_or_help_install(version)
    begin
      vw = VagrantWrapper.new(version)
    rescue Exceptions::Version => e
      $stderr.print e.message + "\n"
      $stderr.print install_instructions
      exit(1)
    end
    vw
  end

  protected

  attr_accessor :search_paths

  # Locate the installed version of Vagrant using the provided paths.
  # Exclude the wrapper itself, should it be discovered by the search.
  def find_vagrant
    unless @vagrant_path
      @search_paths.each do |path|
        test_bin = "#{path}/#{@vagrant_name}"
        next unless ::File.executable?(test_bin)
        next if (%x{tail -n1 #{test_bin}}.force_encoding("ASCII-8BIT").match(@wrapper_mark) != nil)
        @vagrant_path = test_bin
        break
      end
    end
    @vagrant_path
  end

  # Call Vagrant once and return the output of the command.
  def call_vagrant(*args)
    unless vagrant = find_vagrant
      return nil
    end
    args.unshift(vagrant)
    %x{#{Shellwords.join(args)} 2>&1}
  end

  # Give execution control to Vagrant.
  def exec_vagrant(*args)
    unless vagrant = find_vagrant
      $stderr.puts "Vagrant is not installed."
      $stderr.print install_instructions
      exit(1)
    end
    args.unshift(vagrant)
    exec(Shellwords.join(args))
  end
end
