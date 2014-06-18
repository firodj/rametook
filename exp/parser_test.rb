#!/usr/bin/env ruby

require 'logger'
require 'serialport'
require 'thread'
require 'yaml'
require 'iconv'
require 'socket'
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

SmsGateway::Database.load_config('database.yml')
SmsGateway::Database.establish

modem_type = SmsGateway::ModemType.find(:first, :conditions => ['name LIKE ?', "%itegno%"])
puts modem_type.to_yaml

modem_parser = SmsGateway::ModemParser.new( modem_type )
# puts modem_parser.parsers['COMMAND']['+CSQ'].to_yaml
p modem_parser.command('+CSQ', {'length_pdu' => 1, 'data' => '00'})
modem_parser.parse("\r\n+CSQ: 2,5\r\n\r\nOK\r\n")
while modem_parser.parse do
end

p modem_parser.command('+CMGS', {'length_pdu' => 1, 'data' => '00'})
modem_parser.parse("\r\nOK\r\n> ")
while modem_parser.parse do
end

p modem_parser.command('+CSQ', {'length_pdu' => 1, 'data' => '00'})
modem_parser.parse("\r\nOK\r\n")
while modem_parser.parse do
end

p modem_parser.command('+CSQ', {'length_pdu' => 1, 'data' => '00'})
modem_parser.parse("\r\nOK\r\n")
while modem_parser.parse do
end

p modem_parser.command('+CSQ', {'length_pdu' => 1, 'data' => '00'})
modem_parser.parse("\r\nOK\r\n")
while modem_parser.parse do
end

p modem_parser.command('+CSQ', {'length_pdu' => 1, 'data' => '00'})
modem_parser.parse("\r\nOK\r\n")
while modem_parser.parse do
end

p modem_parser.responds
