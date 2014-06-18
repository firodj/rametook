#!/usr/bin/env ruby
#--
#    Rametook - Send/Receive SMS via Modem/Serial-Port
#    Copyright (C) 2007  Fadhil Mandaga
#
#    Rametook is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 3 of the License, or
#    (at your option) any later version.
#
#    Rametook is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>
#++

APP_INFO = "Rametook v0.3.4rc - 2008-05-14"

require 'logger'
require 'serialport'
require 'thread'
require 'yaml'
require 'iconv'
require 'socket'
require 'getoptlong'
require 'rubygems'
require 'daemons'
require 'active_record'
gem 'activerecord'
gem 'daemons'

require 'include/util.rb'
require 'include/modem.rb'
require 'include/device.rb'
require 'include/main.rb'
require 'include/model.rb'
require 'include/pdu.rb'

module SmsGateway
  class Rametook
    # read coniguration
    def self.configure
      cmd = ''
      
      opts = GetoptLong.new(
        [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
        [ '--version', '-v', GetoptLong::NO_ARGUMENT ],
        [ '--color', '-c', GetoptLong::NO_ARGUMENT ],
        [ '--raw', '-r', GetoptLong::NO_ARGUMENT ]
      )    
      
      opts.each do |opt, arg|
        case opt
          when '--color'
            SmsGateway::Utility.debug |= SmsGateway::Utility::COLOR
          when '--raw'
            SmsGateway::Utility.debug |= SmsGateway::Utility::RAW
          when '--help'
            cmd = 'help'
          when '--version'
            cmd = 'version'
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
     
      SmsGateway::Database.load_config('database.yml')
      
      return true      
    end
    
    # print version messages
    def self.show_version
      puts APP_INFO
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
  -h, --help      show help
  -v, --version   show version
  -c, --color     log using color
  -r, --raw       log raw AT command      
END
    end
    
    # print error messages
    def self.show_error
      show_version
      puts "Missing arguments! try --help for usage."
    end
    
    def self.run
      # set current working directory
      file_path = File.expand_path(__FILE__) # File.join(Dir.getwd, __FILE__))
      file_workdir = File.dirname( file_path )
      file_logdir  = File.join(file_workdir, 'log')
      Dir.chdir file_workdir
      
      @@cwd = Dir.getwd  
      @@name = File.basename($0)
      @@hostname = Socket.gethostname
      @@dir = file_workdir 
      APP_INFO << " on #{@@hostname}"
      
      if configure then
        show_version
      
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
      SmsGateway::MainSpooler.start(:dir => @@dir, :name => @@name, :cmd => @@cmd, :hostname => @@hostname)
      clean_pid! if @@cmd == 'start'
    end
      
    # command to stop
    def self.command_stop    
      if get_pid then
        h = File.open("#{@@dir}/#{@@name}.log")
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

SmsGateway::Rametook.run

#SmsGateway::MainSpooler.config(file_workdir, File.basename($0))
#Daemons.run_proc(SmsGateway::MainSpooler.prog_name, {:log_output => true,
#  :ARGV => SmsGateway::MainSpooler.arguments, :multiple => false}) {
#  SmsGateway::MainSpooler.start
#}
