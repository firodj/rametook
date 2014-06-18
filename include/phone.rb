# This file is part of Rametook 0.4

module Rametook

class Phone
  attr_reader :identifier
  attr_reader :modem_device
  attr_reader :modem_type
  
  LIST_STATUSES = ['REC UNREAD','REC READ','STO UNSENT','STO SENT','ALL']
  SMS_MODES = {}
  
  def self.add_sms_mode(name, module_sms_mode)
    SMS_MODES[name] = module_sms_mode
  end
  
  def support_sms_mode?(name)
    if SMS_MODES[name] then
      self.extend(SMS_MODES[name])
      return true
    end
    false
  end
  
  def self.load_modules
    Dir.foreach(File.join(::RAMETOOK_PATH, 'include')) { |file|
      next unless file =~ /phone_.*\.rb/
      require File.join(::RAMETOOK_PATH, 'include', file)
    }   
  end
  
  load_modules
  
  def initialize(modem_device)
    @modem_device = modem_device
    @port = SerialComm.new
    @timeouts = {
      :wait_final_attempts => 3, 
      :read_answer_attempts => 10,
      :delay_between_read_answer => 0.5 }

    # using unknown type to initialize modem parser
    setup_modem_type( ModemType.find_by_id(0) )
  end
    
  def setup_modem_type(modem_type)
    @modem_type = modem_type
    @modem_parser = ModemParser.new( @modem_type )
    
    unless @modem_type.id == 0 then
      if support_sms_mode?(@modem_type.sms_mode) then
        Utility.log_msg "Using #{@modem_type.sms_mode} SMS mode format", @modem_device.device
      else
        Utility.log_err "Unsupported #{@modem_type.sms_mode} SMS mode format", @modem_device.device
        return false
      end
    end

    # get modem function
    @modem_function = {}
    for modem_at_command in @modem_type.modem_at_commands do
      next if modem_at_command.function_name.nil? || modem_at_command.function_name.empty?
      @modem_function[modem_at_command.function_name] = modem_at_command.name
    end
    
    true
  end
  
  # Open serial port
  def open
    Utility.log_msg "Opening connection at #{@modem_device.baudrate} bps #{@modem_device.databits}N#{@modem_device.stopbits} ...", @modem_device.device 
    return false if !@port.open(@modem_device.device)
    begin
      @port.config(@modem_device.baudrate, @modem_device.databits, @modem_device.stopbits, 0, 0) 
      @port.timeout( 50, 10 )
      return true
    rescue Exception => e
      Utility.log_err "open: #{e.message}", @modem_device.device
      return false
    end
  end
	  
  # Close serial port
  def close
    Utility.log_msg "Closing connection...", @modem_device.device
    begin
      # FIXME: seems to wait a long time, if device is not open
      @port.close
    rescue Exception => e
      Utility.log_err "close: #{e.message}", @modem_device.device
    end      
  end
  
  # Write to serial port.
  def write_data(cmd)
    @port.write(cmd)      
    Utility.log_raw(5, '<<', cmd, @modem_device.device)
  end

  # Read from serial port.
  def read_data
    # fill buffer from modem   
    
    buffer = @port.read
    Utility.log_raw(6, '>>', buffer, @modem_device.device) if !buffer.empty?
    return buffer
  end
  
  def start_and_detect
    start
    detect
  end
  
  def start
    # TODO: flush receiver buffer
    
    Utility.log_msg "Starting ...", @modem_device.device    
      
    # initialize, check AT (this not necessary)
    
    write_command('AT')
    
    # IMPORTANT:
    # plase donot put CTRL-Z on command, it will not give answer,
    # bcoz modem don't know if that is a command, not IO bugs!
        
    # disable quiet result
    write_command('ATQ0')
    
    # enable text format result
    write_command('ATV1')
    
    # disable command echo
    write_command('ATE0')
  end
  
  def detect
    Utility.log_msg "Detecting ...", @modem_device.device
    
    # device info
    identifiers = []
    
    write_command('AT+CGMI', {}) # identifier
    while response = fetch_results do
      identifiers << response.name.sub(/\+CGMI:\s+/, '') if response.type == 'STRING'
    end
    
    write_command('AT+CGMM', {}) # model
    while response = fetch_results do
      identifiers << response.name.sub(/\+CGMM:\s+/, '') if response.type == 'STRING'
    end
    
    write_command('ATI0', {})
    while response = fetch_results do
      identifiers << response.name if response.type == 'STRING'
    end
    
    if write_command('AT+CGMR', {}).function == 'success' then # revision
      while response = fetch_results do
        identifiers << response.name.sub(/\+CGMR:\s+/, '') if response.type == 'STRING'
      end
    else
      write_command('ATI3', {})
      while response = fetch_results do
        identifiers << response.name if response.type == 'STRING'
      end
    end
    
    @identifier = identifiers.join('; ').gsub(/[\r\n]+/,'')
    
    # re-initialize modem parser

    if match_modem_type = ModemType.detect_first(@identifier)
      Utility.log_msg "Known modem type: #{match_modem_type.name}", @modem_device.device
      return false unless setup_modem_type( match_modem_type )
    else
      Utility.log_err "Unknown modem type from identifier!", @modem_device.device
    end
    
    return !match_modem_type.nil?
  end
  
  def write_init_commands
    # initialize
    init_commands = (@modem_type.init_command || '').split(';')
    for init_command in init_commands do
      final_response = write_command(init_command)
      
      if final_response.function =~ /_failure$/ then
        if error_message = ModemErrorMessage.get_error_message_for(final_response.function, final_response.params['code'].to_i) then        
          Utility.log_err error_message.message, @modem_device.device
        end
      end      
    end
  end
  
  # Send AT command
  # Process Answer (RESULT/STRING).
  # Return value is final result of array
  def write_command(name, param = {}, &block)
    ret_val = nil
    
    # get command (1st part)
    # if the command dosn't end with CTRL-Z, append CR at the end of command, 
    cmd = @modem_parser.command(name, param)
    
    write_data cmd    
    #cmd += "\r" 
    if !@modem_parser.wait_prompt? # cmd[-1,1] != "\C-z" &&       
      write_data "\r"
    end
        
    wait_final_attempt = @timeouts[ :wait_final_attempts ]
    
    while @modem_parser.wait_final? && wait_final_attempt > 0 do 
      read_answer_attempt = @timeouts[ :read_answer_attempts ]
      
      while read_answer_attempt > 0 do
      
        answer = read_data
        
        
        # parse the answer
        if @modem_parser.parse( answer ) then
          while @modem_parser.parse do end # flush
          # recurrent (force receive all msg)
          read_answer_attempt = @timeouts[ :read_answer_attempts ] 
        else  
          # try again if answer empty
          sleep( @timeouts[:delay_between_read_answer] )
          read_answer_attempt -= 1 if answer.empty?
        end
        
        if !@modem_parser.wait_final? then 
          # final answer got
          ret_val = @modem_parser.last_cmdfin
          read_answer_attempt = 0
        elsif @modem_parser.wait_prompt? && @modem_parser.got_prompt > 0 then 
          # prompt got
          read_answer_attempt = 0
        end
        
      end
      
      # no answer
      ##if answer.empty? then
      ##  wait_final_attempt -= 1          
      ##  return if wait_final_attempt < 0
      ##end

      # next part of command (usually prompted command such as CMGS)
      if @modem_parser.got_prompt > 0 then
        cmd = @modem_parser.next_command
        if cmd then # assert(cmd)
          # cmd += "\r"
          write_data cmd
          
          if !@modem_parser.wait_prompt? # cmd[-1,1] != "\C-z" && 
            sleep(0.5)
            write_data "\r"
          end
        end
      else
        wait_final_attempt -= 1
      end
    end
    
    ret_val
  end
  
  def fetch_results
    @modem_parser.results.shift
  end
  
  def process_pending_unsolics
    answer = read_data
    @modem_parser.parse( answer )
    while @modem_parser.parse do end # flush
    
    while response = @modem_parser.unsolics.shift do
      #Utility.log_msg response.to_yaml, @modem_device.device
      
      unsolic_result = nil
      if !response.function.nil? && 
          respond_to?("when_" + response.function) then
        unsolic_result = send("when_" + response.function, response)
      end
      if block_given? then
        yield( (response.function ? response.function.to_sym : nil), response.params, unsolic_result )
      end
    end
  end
  
  def signal_quality
    final_response = write_command(@modem_function['signal_quality'])
    return if final_response.function != 'success' # raise
    
    while response = fetch_results do
      next if response.function != 'signal_quality' # raise
      return response.params['rssi'].to_i 
    end
  end
  
  def delete_sms(index)
    final_response = write_command(@modem_function['delete_sms'], {'index' => index})
    return if final_response.function != 'success' # raise
    true
  end
  
  def read_sms(index)
    final_response = write_command(@modem_function['read_sms'], {'index' => index})
    return if final_response.function != 'success' # raise
    
    while response = fetch_results do
      next if response.function != 'read_sms'
      
      sms_message = format_read_sms(response.params)
      sms_message.update( 'params' => response.params )
      
      # Logger to SMS Log
      Utility.log_sms @modem_device.device,
        "RECV #{sms_message['status']}", 
        sms_message['service_center_time'] || sms_message['time'],
        index,
        sms_message['number'],
        sms_message['message'], 
        sms_message['log']
      
      return sms_message
    end
  end
  
  def list_sms(status, smslog = false)
    list_status_index = LIST_STATUSES.index(status)
    return if list_status_index.nil?
    
    final_response = write_command(@modem_function['list_sms'], 
      {'status' => format_status_list_sms(list_status_index)})
    
    error_message(final_response)
    
    return if final_response.function != 'success' # raise
    
    sms_messages = []
    while response = fetch_results do
      next if response.function != 'list_sms' # raise
      
      sms_message = format_list_sms(response.params)
      sms_message.update( 'params' => response.params )
      
      if smslog then
        # Logger to SMS Log
        Utility.log_sms @modem_device.device,
          "RECV #{sms_message['status']} LIST",
          sms_message['service_center_time'],
          sms_message['index'],
          sms_message['number'],
          sms_message['message'],
          sms_message['log']
      end
      
      sms_messages << sms_message
    end
    sms_messages
  end
  
  def error_message(final_response)
    return if final_response.function == 'success'
    
    result_val = nil
    
    if final_response.function =~ /failure$/ then
      if modem_error_message = ModemErrorMessage.get_error_message_for(final_response.function, final_response.params['code'].to_i) then
        result_val = modem_error_message.message
      else
        result_val = "#{final_response.function} #{final_response.params['code']}"
      end
    end
    
    if result_val then
      Utility.log_err result_val, @modem_device.device
    end
    
    return result_val
  end
  
  def send_sms(number, message, options = {})
    number = number.gsub(/[\s\+\-\(\)]+/,'') 
    return if number =~ /[^0-9\#\*]+/ # error, invalid format
    
    sms_message = {'number' => number, 'message' => message}.update(options)
    params = format_send_sms(sms_message)
    
    final_response = write_command(@modem_function['send_sms'], params)
        
    error_message(final_response)
    
    return if final_response.function != 'success' # raise
    
    message_ref = -1 # invald: -1
    while response = fetch_results do
      next if response.function != 'send_sms' # raise
      message_ref = response.params['message_ref'].to_i 
    end
    ## return unless message_ref
    
    # Logger to SMS Log
    Utility.log_sms @modem_device.device,
      'SEND',
      Time.now,
      message_ref,
      number,
      message,
      params['log']
    
    message_ref
  end
  
  def hang_up
    final_response = write_command(@modem_function['hang_up'])
    Utility.log_msg "Hang Up", @modem_device.device
  end
  
  # Check if modem has command with specified function
  def has_command?(name)
    has = !@modem_function[name].nil?
    Utility.log_err("doesn't have command \"#{function_name}\"", @modem_device.device) if !has
    has
  end
  
  def when_sms_status_report(response)
    stat_message = format_status_report_sms(response.params)
    stat_message.update( 'params' => response.params )
    
    # Logger to SMS Log
    Utility.log_sms @modem_device.device, 
      'STAT', 
      stat_message['service_center_time'], 
      stat_message['message_ref'], 
      stat_message['number'],
      "#{stat_message['status_report']}: #{stat_message['status']}", 
      stat_message['log']
      
    #strftime('%Y-%m-%d %H:%M:%S')
    
    return stat_message
  end
  
  def when_ring_in(response)
    Utility.log_msg "Ring In", @modem_device.device
  end
  
  def when_caller_id(response)
    Utility.log_msg "Caller ID: #{response.params['number']}", @modem_device.device
  end
    
  def clean_serial_buffer
    write_data("AT\r\n")
    read_data
    write_data("AT\r\n")
    read_data
  end
  
  def test
    write_data("ATI3\r\n")
    read_data

    write_data("AT&V\r\n")
    read_data

    write_data("AT+COPS?\r\n")    
    read_data

    write_data("AT+CSQ\r\n")
    read_data
  end
end

end # :end: Rametook
