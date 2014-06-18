#!/usr/bin/env ruby
require "./SerialComm.so"

os = /-([a-z]+)/.match(RUBY_PLATFORM)[1]
comport = ARGV[0]
raise "Com port ?" if ARGV[0].nil?

p scom = SerialComm.new

p comport

p scom.open( comport )

p scom.config( 115200, 8, 1, 0, 0 )

p scom.timeout( 50, 10 )

print "w:"
p scom.write("ATI3\r\n")
print "r:"
p scom.read

print "w:"
p scom.write("AT&V\r\n")
print "r:"
p scom.read

print "w:"
p scom.write("AT+COPS?\r\n")
print "r:"
p scom.read

print "w:"
p scom.write("AT+CSQ\r\n")
print "r:"
p scom.read

p scom.close
