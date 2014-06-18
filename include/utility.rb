# This file is part of Rametook 0.3.6 (in transition)

require RAMETOOK_PATH + '/include/string.rb'

module Rametook

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
  def self.log_sms(dev, sms, scts, indexref, number, message, pdu = nil)
    if sms =~ /^SEND/
      log_msg "Send SMS to #{number} (#{indexref})", dev
    elsif sms =~ /^RECV/
      log_msg "Receive SMS from #{number} [#{indexref}]", dev
    elsif sms =~ /^STAT/
      log_msg "Receive SMS status report #{number} (#{indexref})", dev
    end
    
    #str = '[' + Time.now.strftime("%Y-%m-%d %H:%M:%S") +"] \t#{d}\t#{t}\t#{info}\t" + pretty(msg)
    
    str = [dev, sms, scts, indexref, number, message, pdu].to_yaml
    
    begin; @@sms_logger.info str; rescue Exception => e; end
  end
  
  # load rails envirnment
  def self.load_rails_environment(rails_env = 'development')
      ENV["RAILS_ENV"] = rails_env
      RAILS_ENV.replace(rails_env) if defined?(RAILS_ENV)
      require RAILS_ROOT + '/config/environment'
      ActiveRecord::Base.allow_concurrency = true
    end
end

end # :end: Rametook

