# encoding: UTF-8
require 'open3'

module EasyType
  #
  # The EasyType:Daemon class, allows you to easy write a daemon for your application utility.
  # To get it working, subclass from
  #
  # rubocop:disable ClassVars
  class Daemon
    SUCCESS_SYNC_STRING = /~~~~COMMAND SUCCESFULL~~~~/
    FAILED_SYNC_STRING = /~~~~COMMAND FAILED~~~~/
    TIMEOUT = 120 # wait 2 minutes

    @@daemons = {}
    #
    # Check if a daemon for this identity is running. Use this to determin if you need to start the daemon
    #
    def self.run(identity)
      daemon_for(identity) if daemonized?(identity)
    end

    # @nodoc
    def initialize(identifier, command, user)
      if @@daemons[identifier]
        return @@daemons[identifier]
      else
        initialize_daemon(user, command)
        @identifier = identifier
        @@daemons[identifier] = self
      end
    end

    #
    # Pass a command to the daemon to execute
    #
    def execute_command(command)
      @stdin.puts command
    end

    #
    # Wait for the daemon process to return a valid sync string. YIf your command passed
    # ,return the string '~~~~COMMAND SUCCESFULL~~~~'. If it failed, return the string '~~~~COMMAND FAILED~~~~'
    #
    #
    def sync( &proc)
      @stdout.each_line do |line|
        Puppet.debug "#{line}"
        break if line =~ SUCCESS_SYNC_STRING
        fail 'command in deamon failed.' if line =~ FAILED_SYNC_STRING
        proc.call(line) if proc
      end
    end

    private

    # @nodoc
    def self.daemonized?(identity)
      !daemon_for(identity).nil?
    end

    # @nodoc
    def self.daemon_for(identity)
      @@daemons[identity]
    end

    # @nodoc
    def initialize_daemon(user, command)
      if user
        @stdin, @stdout, @stderr = Open3.popen3("su - #{user}")
        execute_command(command)
      else
        @stdin, @stdout, @stderr = Open3.popen3(command)
      end
    end
  end
  # rubocop:enable ClassVars
end
