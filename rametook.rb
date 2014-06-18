#!/usr/bin/env ruby
#--
#    Rametook - Send/Receive SMS via Modem/Serial-Port
#    Copyright (C) 2007  Fadhil Mandaga
#++

APP_INFO = "Rametook v0.3.7rc - 2008-08-04"

require File.dirname(__FILE__) + '/boot'

module Rametook
  class Application
    @@rails_env = ENV['RAILS_ENV'] ? ENV['RAILS_ENV'].dup : "development"
      
    # read coniguration
    def self.configure
      cmd = ''
      
      opts = GetoptLong.new(
        [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
        [ '--version', '-v', GetoptLong::NO_ARGUMENT ],
        [ '--color', '-c', GetoptLong::NO_ARGUMENT ],
        [ '--raw', '-r', GetoptLong::NO_ARGUMENT ],
        [ '--environment', '-e', GetoptLong::REQUIRED_ARGUMENT]
      )    
      
      opts.each do |opt, arg|
        case opt
          when '--color'
            Rametook::Utility.debug |= Rametook::Utility::COLOR
          when '--raw'
            Rametook::Utility.debug |= Rametook::Utility::RAW
          when '--help'
            cmd = 'help'
          when '--version'
            cmd = 'version'
          when '--environment'
            @@rails_env = arg         
        end
      end
                
      if cmd == 'version' then
        show_version
        return false
      elsif cmd == 'help' then
        show_help
        return false
      else
        cmd = ARGV.shift
        if !['start','stop','run','restart'].include?(cmd) then
          show_error
          return false
        end
        @@cmd = cmd
      end
     
      # Rametook::Database.load_config('database.yml')
      
      return true      
    end
    
    # print version messages
    def self.show_version
      puts APP_INFO + ' -- ' + @@rails_env
    end
    
    # print help messages
    def self.show_help
      show_version
      puts <<END
== Synopsis

== Usage

#{@@name} [OPTION] COMMAND

Command:
  run         start and run in front
  start       run in background (daemon)
  stop        terminate background
  restart     stop then start
  
Options:
  -h, --help        show help
  -v, --version     show version
  -c, --color       log using color
  -r, --raw         log raw AT command      
  -e, --environment rails environment (db)
END
    end
    
    # print error messages
    def self.show_error
      show_version
      puts "Missing arguments! try --help for usage."
    end
    
    def self.run
      # set current working directory
      #file_path = File.expand_path(__FILE__) # File.join(Dir.getwd, __FILE__))
      #file_workdir = File.dirname( file_path )
      #file_logdir  = File.join(file_workdir, 'log')
      Dir.chdir RAMETOOK_PATH
      
      #@@cwd = Dir.getwd  
      @@name = File.basename($0)
      #@@hostname = Socket.gethostname
      @@dir = Dir.getwd 
      #APP_INFO << " on #{@@hostname}"
      
      if configure then
        show_version
        
        Utility.load_rails_environment(@@rails_env)
        #DeviceSpooler.init_constants
              
        stopped = if ['stop','restart'].include?(@@cmd) then
          command_stop
        end

        if ['run','start','restart'].include?(@@cmd) && stopped != false then                 
          @@cmd = 'start' if @@cmd == 'restart'
          command_start
        end
      
      end
    end
    
    # get pid of within same application name
    def self.get_pid
      @@pid = nil
      @@file_pid = nil
      files = Dir[File.join(@@dir, "#{@@name}.pid")]      
      files.each {|f| if (File.file?(f) and File.readable?(f)) then
          pid = File.open(f) {|h| h.read}.to_i
          if running_pid?(pid) then
            @@file_pid = f
            @@pid = pid
          else
            puts "pid-file for killed process #{pid} found (#{f}), deleting."
            begin; File.unlink(f); rescue ::Exception; end
          end
        end
      }
      @@pid
    end
    
    # write current Process.pid
    def self.write_pid!
      @@pid = Process.pid
      File.open("#{@@dir}/#{@@name}.pid", 'w') {|h|
        h.puts @@pid   #Process.pid
      }
    end
    
    # clean up current Process.pid
    def self.clean_pid!
      begin; File.unlink("#{@@dir}/#{@@name}.pid"); rescue ::Exception; end
    end
    
    # check if given +pid+ is running
    def self.running_pid?(pid)
      return false if pid.nil?
      begin
        Process.kill(0, pid)
        return true
      rescue Errno::ESRCH
        return false
      rescue Errno::EPERM   
        # for example on EPERM (process exists but does not belong to us), ex. as root
        return true
      rescue # ::Exception
      end
      return false
    end
    
    # command to start
    def self.command_start
      if get_pid then
        puts "Found other #{@@name} running #{@@pid}!"
        return
      end           
      Rametook::MainSpooler.start(:dir => @@dir, :name => @@name, :cmd => @@cmd)
        # , :hostname => @@hostname
      clean_pid! if @@cmd == 'start'
    end
      
    # command to stop
    def self.command_stop    
      if get_pid then
        h = File.open("#{@@dir}/log/#{@@name}.log")
        h.seek(0, IO::SEEK_END) if h
        
        begin
          Process.kill("TERM", @@pid)
        rescue Errno::ESRCH => e
          puts "#{e} #{@@pid}"
          puts "deleting pid-file."
        rescue Errno::EPERM => e
          puts "#{e} #{@@pid}"
          puts "please login (su) as apropriate user (maybe root)."
          return false
        else
          # write tail log
          if h then
            # wait until the pid stops! and also write the tail log
            while running_pid?(@@pid)
              while s = h.gets do
                puts s
              end
              sleep(0.25)
            end
            # write the latest tail log
            while s = h.gets do
              puts s
            end             
            h.close
          end          
        end
        
        begin; File.unlink(@@file_pid); rescue ::Exception; end                
      else
        puts "Nothing to stop!"        
      end
      return true
    end      
    
    # daemonize
    def self.daemonize
      if @@cmd == 'start' then
        Daemonize.daemonize( "#{@@dir}/#{@@name}.log" )
        write_pid!
        return true
      end
    end
         
  end
end

Rametook::Application.run

#Rametook::MainSpooler.config(file_workdir, File.basename($0))
#Daemons.run_proc(Rametook::MainSpooler.prog_name, {:log_output => true,
#  :ARGV => Rametook::MainSpooler.arguments, :multiple => false}) {
#  Rametook::MainSpooler.start
#}
