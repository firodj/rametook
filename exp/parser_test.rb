#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../boot'
Rametook::Utility.load_rails_environment

modem_type = Rametook::ModemType.find(:first, :conditions => ['name LIKE ?', "%itegno%"])
puts modem_type.to_yaml

modem_parser = Rametook::ModemParser.new( modem_type )
# puts modem_parser.parsers['COMMAND']['+CSQ'].to_yaml
p modem_parser.command('+CSQ', {'length_pdu' => 1, 'data' => '00'})
modem_parser.parse("\r\n+CSQ: 2,5\r\n\r\nOK\r\n")
while modem_parser.parse do
end

p modem_parser.command('+CMGS', {'length_pdu' => 3, 'data' => '00112233'})
modem_parser.parse("\r\n> ")
p modem_parser.next_command
modem_parser.parse("\r\nRING\r\n\r\n+CMGS: 200\r\n\r\nOK\r\n")
while modem_parser.parse do
end

p modem_parser.command('+CMGL', {'status' => 4})
modem_parser.parse("\r\n+CMGL: 1,0,,125\r\n07912638510000130407D0416C720A0000807091018404827BCA3039BD0EBB41ECF0B90E2A5283D020881C96A741D36CF51804CDCBE2F0399C064985D476DD051A86E561773E0C5A97E9E935E8E9DCF0E6F0F03CBDF1C17031D84C9603B1C3EC3A689D96A7DBA07519349BCD5CA0A33C4C4FCF41E4B03C0D0A6293531748184EAF41F9F00F\r\n\r\nOK\r\n\r\n+CMTI: \"SM\",1\r\n")
while modem_parser.parse do
end

p modem_parser.command('+CSQ', {'length_pdu' => 1, 'data' => '00'})
modem_parser.parse("\r\nOK\r\n")
while modem_parser.parse do
end

modem_parser.get_responses { |responses|
  p responses
}
