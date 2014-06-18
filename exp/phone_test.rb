#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../boot'
Rametook::Utility.load_rails_environment

require RAMETOOK_PATH + '/include/phone.rb'

Rametook::Utility.debug |= Rametook::Utility::RAW
Rametook::Utility.debug |= Rametook::Utility::COLOR

ModemErrorMessage.init_constants

modem_device = Rametook::ModemDevice.find(:first, :conditions => ['device LIKE ?', '%ttyUSB0'])

phone = Rametook::Phone.new( modem_device )
phone.open
phone.clean_serial_buffer
phone.start_and_detect
y phone.identifier

phone.write_init_commands

phone.list_sms('ALL').each { |sms_message|
  y phone.read_sms(sms_message['index'])
}

#y phone.send_sms('0838 859 6327', "this is a testing message")
#y phone.send_sms('0815 700 5396', "this is a testing message")

looping = true
trap "INT", Proc.new { looping = false }
while looping do
  y phone.signal_quality
  phone.process_pending_unsolics
  sleep(1)
end

phone.close

