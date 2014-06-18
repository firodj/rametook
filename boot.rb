# This file is part of Rametook 0.3.6 (in transition)

RAMETOOK_OS = /-([a-z]+)/.match(RUBY_PLATFORM)[1]

require 'logger'

require 'thread'
require 'yaml'
require 'iconv'
#require 'socket'
require 'getoptlong'

require 'rubygems'

require 'daemons'
gem 'daemons'

require 'SerialComm' # ruby-serialcomm

RAMETOOK_PATH = File.dirname( File.expand_path(__FILE__) )

%w(utility 
modem_parser 
task_queue 
phone 
device_spooler 
main_spooler 
autoreply).each { |fn|
  require RAMETOOK_PATH + '/include/' + fn
}

require File.dirname(__FILE__) + '/../../config/boot'



