#--
#    This file is part of Rametook
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

module SmsGateway

  # This class hold a set of utility methods for outputting log and error
  # message
  class Utility
    NONE  = 0 
    
    # +debug+ flag for enabling raw log  
    RAW   = 1 
    
    # +debug+ flag for coloring log
    COLOR = 2 
    
    @@debug = NONE
    @@sms_logger = nil
    @@today = nil

    # Write +debug+ flags.
    def self.debug=(val)
      @@debug = val
    end
    
    # Read +debug+ flags.
    def self.debug
      @@debug
    end

    # Make pretty output that will visualize invisible characters like <CR>, 
    # <LF>, <CTRL-Z>, that usually found in AT command.
    def self.pretty(str, c = nil) 
      escape_str = { "\r" => '<CR>', "\n" => '<LF>', "\C-z" => '<CTRL-Z>', "\e" => '<ESC>' }
      s = ''  
      str.each_byte { |x|
        x = x.chr
        if escape_str[x].nil? then
          s << x
        else
          if (@@debug & COLOR == COLOR ) && !c.nil? then
            s << "\e[3#{c}m" + escape_str[x] + "\e[9#{c}m"
          else 
            s << escape_str[x]
          end 
        end
      } if !str.nil?
      s
    end

    # Get date and time for output message. If date from current call is
    # different from last call, the time will be prepend with date, otherwise
    # only time.
    def self.get_time
      time  = Time.now
      today = time.strftime("%Y-%m-%d")
      clock = time.strftime("%H:%M:%S")
      s = ''
      if today != @@today 
        s << "<#{today}>\n" 
        @@today = today
      end
      s << "[#{clock}] "
      s
    end

    # Print log from raw AT command using +pretty+ output
    # [+c+] Fixnum, color number (5: magenta: 6 cyan)
    # [+prestr+] String, info string
    # [+rawstr+] String, raw AT to print.
    # [+d+] String / Nil, device name.
    def self.log_raw(c, prestr, rawstr, d = nil)
      return if !(@@debug & RAW == RAW)      
      s = get_time
      s << ((@@debug & COLOR == COLOR) ? ("\e[1m" + d + "\e[0m ") : (d + ' ')) if !d.nil?
      s << prestr + ' '
      s << ((@@debug & COLOR == COLOR) ? ("\e[9#{c}m" + pretty(rawstr, c) + "\e[0m") : pretty(rawstr, c))  
      puts s
    end
    
    # Print log message.
    # [+str+] String, message to print.
    # [+d+] String / Nil, device name.
    def self.log_msg(str, d = nil)
      s = get_time
      s << ((@@debug & COLOR == COLOR) ? ("\e[1m" + d + "\e[0m ") : (d + ' '))  if !d.nil?
      s << str
      puts s
    end
  
    # Print error message.
    # [+str+] String, message to print.
    # [+d+] String / Nil, device name. 
    def self.log_err(str, d = nil)
      s = get_time
      s << ((@@debug & COLOR == COLOR) ? ("\e[1;91m" + d + "\e[0m ") : (d + ' '))  if !d.nil?
      s << ((@@debug & COLOR == COLOR) ? ("\e[91m" + str + "\e[0m ") : str)
      puts s
    end

    # Open sms logger file <tt>file_name</tt> to write sms log.
    def self.sms_logger_open(file_name)
      @@sms_logger = Logger.new("#{file_name}.smslog") #, 'monthly'
      @@sms_logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    end
    
    # Close sms logger.
    def self.sms_logger_close
      @@sms_logger.close
    end
    
    # Write sms log to sms logger that was opened by +sms_logger_open+.
    # [+t+] String, type of SMS: SEND, RECV, or STAT.
    # [+info+] String, info of SMS such as phone number.
    # [+msg+] String, SMS content.
    # [+d+] String, device name.
    def self.log_sms(t, info, msg, d)            
      case t 
        when 'SEND'
          log_msg "Send SMS to #{info}", d
        when 'RECV'
          log_msg "Receive SMS from #{info}", d
        when 'STAT'
          log_msg "Receive SMS status report #{info}", d
      end
      str = '[' + Time.now.strftime("%Y-%m-%d %H:%M:%S") +"] \t#{d}\t#{t}\t#{info}\t" + pretty(msg)
      begin; @@sms_logger.info str; rescue Exception => e; end
    end
  end 
end

class String
  def to_time
    # FIXME: see ActiveSupport
    t = self.scan(/([0-9]+)\/([0-9]+)\/([0-9]+),([0-9]+)\s\:([0-9]+)\s\:([0-9]+)/)
    begin
      Time.local(t[0][0], t[0][1], t[0][2], t[0][3], t[0][4], t[0][5])
    rescue ArgumentError
      nil
    end
  end
end
