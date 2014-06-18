#!/usr/bin/env ruby
require "serialport"

if ARGV.size < 4
  STDERR.print <<EOF
  Usage: ruby #{$0} num_port bps nbits stopb
EOF
  exit(1)
end

device_name = ARGV[0]
if device_name.scan(/[^0-9]+/).empty? then
  device_name = device_name.to_i  
end

puts "Device: #{device_name}"
sp = SerialPort.new(device_name, ARGV[1].to_i, ARGV[2].to_i, ARGV[3].to_i, SerialPort::NONE)
color_mode = true if ARGV[4] && ARGV[4] == '--color'

trap "TSTP", Proc.new {
  sp.write("\C-z")
} # Ctrl-Z trap

# taken from SmsGateway::Utility
def log_raw(rawstr)
  c = 3
  !c.nil? ? ("\e[9#{c}m" + pretty(rawstr, c) + "\e[0m") : pretty(rawstr, c)
end
def pretty(str, c = nil) 
  escape_str = { "\r" => '<CR>', "\n" => '<LF>', "\C-z" => '<CTRL-Z>', "\e" => '<ESC>' }
  s = ''
  ce = 6
  str.each_byte { |x|
    x = x.chr
    if escape_str[x].nil? then
      s << x
    else
      if !c.nil? then
        s << "\e[3#{ce}m" + escape_str[x] + "\e[9#{c}m"
      else 
        s << escape_str[x]
      end 
    end
  } if !str.nil?
  s
end
# -- end of taken

open("/dev/tty", "r+") { |tty|
  tty.sync = true
  Thread.new {
    while true do
      while IO.select([sp],[],[],0.25) do
        if color_mode
          tty.printf("%s", log_raw(sp.getc.chr) )
        else
          tty.printf("%c", sp.getc )
        end
        
      end
    end
  }
  while (l = tty.gets) do
    l = "\r" if l == "\n"
    sp.write(l.sub("\n", ""))
  end
}

sp.close
