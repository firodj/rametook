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

  # This class is device spooler that communicate with modem.
  class DeviceSpooler
    attr_reader :restart

    def initialize(modem_device)
      @terminate = false
      @request_to_terminate = false
      @thread    = nil      
      @restart   = false
      @ready     = false # gateway ready

      @mutex_inbox  = Mutex.new
      @mutex_outbox = Mutex.new
      @inbox  = []
      @outbox = []
      @sm_process = nil # processed short message
      @sm_incomes = {}  # index => fetched or not
 
      @rx_timeout = 0.05
      
      @pdu_mode = false
      @ring_in_hang_up = nil
      @identifier = ''

      @max_inbox = 20
      @min_inbox = 5
      @prior_inbox = false

      @modem_device = modem_device
      Utility.log_msg "Initializing ...", @modem_device.device    
      @modem_type   = modem_device.modem_type
           
      # initialize modem parser
      @modem_parser = ModemParser.new( @modem_type )
      @pdu_mode = @modem_type.pdu_mode # || 0).to_i == 1
      @also_read_when_list = false # only available on PDU: experimental, default: false
       
      # get modem function
      @modem_function = {'answer_call' => 'A', 'hang_up' => 'H'} 
      for modem_at_function in @modem_type.modem_at_functions do
        @modem_function[modem_at_function.name] = modem_at_function.command_name
      end
       
      @restart = true
    end

    # Access outbox array to the given block. Outbox contains messages/commands
    # to device spooler.
    def outbox
      ret = nil
      @mutex_outbox.synchronize {        
        ret = yield @outbox if block_given?
      }
      return ret 
    end

    # Access inbox array to the given block. Inbox contains messages/command
    # to main spooler.
    def inbox
      ret = nil
      @mutex_inbox.synchronize {
        ret = yield @inbox if block_given?
      }
      return ret
    end

    # Return the number of outbox to submit (in queue)
    def number_outbox_submit
      n = @sm_process.nil? ? 0 : 1
      outbox { |box|
        box.each { |mail| n += 1 if mail['type'] == 'submit' }
      }
      n
    end
    
    # Return true if inbox and outbox are empty (indicate device don't hv job)
    def empty_box?
      ob = outbox { |box| box.size }
      ib = inbox  { |box| box.size }
      (ob + ib) == 0
    end
    
    # Return true if thread is still running (alive).
    def running?
      return false if @thread.nil?
      return @thread.alive?
    end
    
    # Return true if device is ready for sms gateway
    def ready?
      return @ready
    end
    
    # Return true if device is being terminate
    def terminating?
      return @terminate
    end

    # Starting device spooler, creating a thread and become device loop.
    #
    # This method performs:
    # - open serial port
    # - start modem initialize
    # - device looping
    # - receive queued sms, and send queued sms
    # - read notify
    def run
      # just skip this, if already running
      @restart = false
      return true if running?

      @thread = Thread.new {         
        check_sq_cnt = 0
        if open then
	        if start then
	          @ready = true
	          while @ready do
              w_r = w_t = true
              
              accept_terminate
                            
              if !@terminate then
	              # Receive SMS
	              w_r = receive_sms
	            end
              
              accept_terminate
              
	            # Send SMS (or Delete SMS)
	            w_t = transmit_sms
	            
	            accept_terminate
	            
	            if !@terminate then
	              # Get Notify
	 	            notify_at
		        
		            # Check signal quality
		            check_signal_quality if check_sq_cnt == 0
		            check_sq_cnt = (check_sq_cnt + 1) % 5
		            
		            # Wait a little to save CPU
		            if w_r && w_t then
		              sleep(2)
		            end
		          end		            
	          end
	          @ready = false 
	        else
	          @restart = true
	        end
          close
        end

        @terminate = false
        Utility.log_msg "End.", @modem_device.device
      }        
    end
      
    # Send stop signal to device spoooler for finalize all jobs.
    def stop      
      @request_to_terminate = true if running?
    end    

    # This method will tell device spooler to exit loop.
    def ready_to_stop
      @ready = false
    end
    
    private

    # Start modem initialization
    def start
      # flush modem buffer, first,
      notify_at
      #- flush_responds
      #- immediate_commands

      # TODO: flush receiver buffer, from modem (grabage, unknwon data)
      # Also, it is better to reset the modem by hand (turn-off then turn-on).
      # bcoz, if it start when the modem in the middle of receiving uncompleted
      # command, you know lah, all of AT command will be not to be known
      # The very danger in the middle of Inputing Message.
      
      # initialize, check AT (this not necessary)
      command_then_answer_at("AT")
      # IMPORTANT:
      # plase donot put CTRL-Z on command, it will not give answer,
      # bcoz modem don't know if that is a command, not IO bugs!
          
      # disable quiet result
      command_then_answer_at('ATQ0')
      
      # enable text format result
      command_then_answer_at('ATV1')
      
      # disable command echo
      command_then_answer_at('ATE0')
      
      #---------------------------
 
      # device info
      identifiers = []
      
      command_then_answer_at('ATI0', {}) { |x| identifiers << x[1] if x[0] == 'STRING' }
      ##command_at('ATI0')
      ##answer_at { |x| identifiers << x[1] if x[0] == 'STRING' }
      
      command_then_answer_at('ATI3', {}) { |x| identifiers << x[1] if x[0] == 'STRING' } 
      ##command_at('ATI3')
      ##answer_at { |x| identifiers << x[1] if x[0] == 'STRING' }
      
      @identifier = identifiers.join('; ').gsub(/[\r\n]+/,'')
      Utility.log_msg @identifier, @modem_device.device
            
      # initialize
      init_commands = @modem_type.init_command.split(';') + @modem_device.init_command.split(';')
      for init_command in init_commands do
        command_then_answer_at(init_command)
        ##command_at(init_command)
        ##answer_at
      end
      
      # save info to db
      inbox { |box| box.push( {'type' => 'others', 'data' => {'identifier' => @identifier}} )}
      
      # for debug only:
      #- flush_responds
      #- immediate_commands

      Utility.log_msg "Ready.", @modem_device.device      
      true
    end

    # Accept terminate if terminate has been requested
    def accept_terminate
      if @request_to_terminate
        Utility.log_msg "Terminating signal received.", @modem_device.device
        @terminate = true 
        @request_to_terminate = false
      end
    end

    # Open serial port
    def open
      Utility.log_msg "Opening connection at #{@modem_device.baudrate} bps #{@modem_device.databits}N#{@modem_device.stopbits} ...", @modem_device.device 
      begin     
        @port = SerialPort.new(@modem_device.device,
	        @modem_device.baudrate, 
	        @modem_device.databits,
	        @modem_device.stopbits, SerialPort::NONE)
	      return true
	    rescue Exception => e
	      Utility.log_err "open: #{e.message}", @modem_device.device
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

    # Process queued messages/commands in outbox.
    def transmit_sms      
      workless = true
      n = 0
      
      while !(mail = outbox { |box| box.shift }).nil? do
        workless = false
        case mail['type'] 
          when 'submit'
            if @prior_inbox then 
              # don't sent now, push again
              # FIXME: possible unnecessary mail loop-back in mail and
              #        uninfinite loop.
              outbox { |box| box.push mail }
            else
              if has_command?('send_sms') && do_command('send_sms', mail['data']) then
                do_wait('sms_status_report')
              end
            end                
            n += 1
            
          when 'destroy'            
            index = mail['data']['index'].to_i
            if @sm_incomes[index]
              # Delete a sms for Real!
              do_command('delete_sms', {'index' => index})if has_command?('delete_sms')
                
              # DO it here, or in on_ok
              #   @sm_incomes.delete index
            end
            if @prior_inbox && @sm_incomes.size <= @min_inbox               
              @prior_inbox = false 
              Utility.log_msg "Read priority [OFF], SMS to read #{@sm_incomes.size}", @modem_device.device
            end
        end

        #break if @terminate
        break if n >= 1
      end

      workless
    end

    # Receive messages to inbox.
    def receive_sms      
      workless = true
      list_status = @pdu_mode ? 4 : 'ALL'
      
      return workless if !has_command?('list_sms')
      
      if @sm_incomes.empty?
        do_command('list_sms',{'status' => list_status}) 
        Utility.log_msg "Incoming #{@sm_incomes.size} SMS", @modem_device.device if @sm_incomes.size > 0

        # DEBUG
        #@sm_incomes.clear
        #
        
        if @sm_incomes.size >= @max_inbox
          @prior_inbox = true 
          Utility.log_msg "Read priority [ON], SMS to read #{@sm_incomes.size}", @modem_device.device
        end
      end
      
      return workless if !has_command?('read_sms')

      n = 0
      @sm_incomes.each do |index, fetched|         
        next if fetched
        
        workless = false
        do_command('read_sms', {'index' => index})
        
        @sm_incomes[index] = true # fetched        

        n += 1
        break if n >= 1
        #break if @terminate
      end
      workless
    end

    # Check signal quality.
    def check_signal_quality
      return if !has_command? 'signal_quality'
      
      do_command('signal_quality')
    end
    
    # Read all pending responds form last AT command, or incoming unsoliciated
    # AT command.
    def flush_responds
      y = []
      @modem_parser.get_responds { |x|                
        case x[0]
          when 'UNSOLIC'
            function_name = @modem_function.index(x[1]) || x[1]
            on_notify(function_name, x)
          else
            if !x[0].nil? then
              y = x if x[0] == 'FINAL'
              yield x if block_given?
            end
        end        
      }
      y
    end    
    
=begin
    # DEPRECATED, DELETE ME!
    # Send AT command
    def command_at(name, param = {})
      cmd = @modem_parser.command(name, param)
      
      first_cr = cmd.index "\r"
      if !first_cr.nil? then
        cmd_head = cmd[0..first_cr]
        dev_tx(cmd_head)        
        sleep 2 # wait low-layer stupid modem to do this f**kin setup
        sia = dev_rx
        p sia
        cmd = cmd[(first_cr+1)..-1]        
      end
      # FIXME: prompt must be coding wait!
      
      cmd += "\r" if cmd[-1,1] != "\C-z"
      dev_tx(cmd)
    end    

    # DEPRECATED, DELETE ME!
    # Process Answer (RESULT/STRING).
    # Return value is final result of array
    def answer_at(&block)
      return if !@modem_parser.wait_final?
      ret_val = nil

      try_attempt = 10
      while try_attempt > 0 do
        answer = dev_rx
        # parse the answer
        if !@modem_parser.parse( answer ) then # try again if still empty
          sleep(0.5)
          try_attempt -= 1 if answer.empty?
        elsif !@modem_parser.wait_final? then # final got
          ret_val = @modem_parser.last_cmdfin
          try_attempt = 0
        else # recurrent bcoz waiting final
          try_attempt = 10 # recurrent
        end
      end
      
      # DEBUG
      #Utility.log_msg "Answer try attempt: #{try_attempt}", @modem_device.device
      #
      
      flush_responds { |x| block.call x if !block.nil? }
      immediate_commands

      ret_val
    end
=end
    
    # new version: for command_at then answer_at
    # Send AT command
    # Process Answer (RESULT/STRING).
    # Return value is final result of array
    def command_then_answer_at(name, param = {}, &block)
      # get command (1st segment)
      cmd = @modem_parser.command(name, param)
      # just add CR (\r) for last segment of at command, and not ended with CTRL-Z
      cmd += "\r" if cmd[-1,1] != "\C-z" && !@modem_parser.wait_prompt?
      dev_tx(cmd)
      
      # answer
      ret_val = nil
      wait_final_attempt = 3
      
      while @modem_parser.wait_final?
        try_attempt = 10
        while try_attempt > 0 do
          answer = dev_rx
          
          # parse the answer
          if @modem_parser.parse( answer ) then # recurrent (force receive all msg)
            try_attempt = 10 # recurrent  
          else  # try again if still empty
            sleep(0.5)
            try_attempt -= 1 if answer.empty?
          end
          
          if !@modem_parser.wait_final? then # final answer got
            ret_val = @modem_parser.last_cmdfin
            try_attempt = 0
          elsif @modem_parser.wait_prompt? && @modem_parser.got_prompt > 0 then # prompt got
            try_attempt = 0
          end
        end
        
        # no answer!??
        if answer.empty? then
          wait_final_attempt -= 1
          if wait_final_attempt < 0 then
            Utility.log_err("command never give final answer, self-terminate", @modem_device.device)
            @terminate = 1
          end
          break if @terminate
        end
              
        #
        flush_responds { |x| block.call x if !block.nil? }
        immediate_commands
        
        ## next command
        if @modem_parser.got_prompt > 0 then
          cmd = @modem_parser.next_command
          if cmd then # assert(cmd)
            cmd += "\r" if cmd[-1,1] != "\C-z" && !@modem_parser.wait_prompt?
            dev_tx(cmd)
          end
        end
        
      end
      ret_val
    end
   
    # Process Notify (UNSOLIC).
    def notify_at(&block)
      answer = dev_rx
      @modem_parser.parse( answer )     

      ret_val = flush_responds{|x| block.call x if !block.nil?}
      immediate_commands

      ret_val
    end
  
    # Write to serial port.
    def dev_tx(cmd)
      # select when serialport available for write
      # IO.select([], [@port], [], @rx_timeout)
      # we need not that IO.select for now!
      @port.write(cmd)      
      Utility.log_raw(5, '<<', cmd, @modem_device.device)
    end

    # Read from serial port.
    def dev_rx
      # fill buffer from modem
      buffer = ''
      
      while true do
        # select when serialport available for read
        port_selected = IO.select([@port], [], [], @rx_timeout)
        
        if port_selected then
          chr = @port.getc.chr
          buffer += chr
        else
          break
        end      
      end

      Utility.log_raw(6, '>>', buffer, @modem_device.device) if !buffer.empty?
      buffer
    end

    # Immediate Action
    def immediate_commands
      if !@ring_in_hang_up.nil? then        
        @ring_in_hang_up = nil
        
        if has_command?('hang_up') && do_command('hang_up') then
          Utility.log_msg "Hang Up", @modem_device.device
          # do_wait('+WEND')
        end        
      end
    end
    
    # Check if modem has command with specified function
    def has_command?(function_name)
      has = !@modem_function[function_name].nil?
      Utility.log_err("doesn't have command \"#{function_name}\"", @modem_device.device) if !has
      has
    end
    
    # Create command then send.
    def do_command(function_name, parameters={})
      parameters = param_for_command(function_name, parameters)
      fin = command_then_answer_at(@modem_function[function_name], parameters) { |x| 
        on_result(function_name, parameters, x) if x[0] == 'RESULT'
      } 
      ##command_at(@modem_function[function_name], parameters)
      ##fin = answer_at { |x| on_result(function_name, parameters, x) if x[0] == 'RESULT' }
      
      # FIXME:, [] ??
      # DEBUG
      #Utility.log_msg 'Final result command: ' + fin.inspect, @modem_device.device
      #
      
      fin[1] == 'OK' ? on_ok(function_name, parameters, fin) : on_error(function_name, parameters, fin)
    end
    
    # Wait unsolic after command.
    def do_wait(function_name)
      case function_name 
        when 'sms_status_report'
          attempt_to_wait = 10
          while attempt_to_wait > 0 do
            # wait for sms-status-report from tower
            notify_at
            
            # on_notiy 'sms_sms_report' will make @sm_process = nil if
            # status report received
            if @sm_process.nil? then            
              attempt_to_wait = 0
            else
              sleep 1
              attempt_to_wait -= 1 
            end
          end
          
          if !@sm_process.nil? then
            inbox { |box| box.push( {'type' => 'status', 'data' => @sm_process.update({'status' => 'WAITING'})} ) }
            @sm_process = nil
            Utility.log_err 'Time out waiting SMS status report', @modem_device.device
          end
      end 
    end
    
    # Change parameters before command.
    def param_for_command(function_name, parameters)
      case function_name
        when 'send_sms'
          if @pdu_mode then
            pdu_info = { 'first_octet' => ['sms-submit', 'v-rel', 'tp-srr'], 
						  'message_ref' => 00,
						  'number' => parameters['number'],
						  'validity_period' => 0xAA,
						  'message' => parameters['message'] }
            pdu, length_pdu = PDU.write( pdu_info )
						parameters['length_pdu'] = length_pdu
            parameters['data'] = pdu
            parameters['pdu_info'] = pdu_info
          else
            parameters['data'] = parameters['message']
          end
          
          # set sm_process, that we are sending sms and 
          # waiting tower for response
          @sm_process = parameters
      end
      parameters
    end
    
    # Change parameters after result.
    def param_for_result(function_name, parameters)
      case function_name
        when 'read_sms'
          if @pdu_mode then
            pdu_info = PDU.read(parameters['data'], parameters['length_pdu'].to_i)
            parameters['message'] = pdu_info['message']
            parameters['service_time'] = pdu_info['service_time']
            parameters['number'] = pdu_info['number']
            # save pdu info for pdu-log
            parameters['pdu_info'] = pdu_info
            parameters['status'] = case parameters['status'].to_i
              when 2 #STO UNSENT
                'DRAFT'
              when 3 #STO SENT
                'SENT'
              else #0:REC UNREAD,1:REC READ
                'INBOX'
              end
          else
	          message = parameters['data']
	          unless (encode = parameters['encode']).nil? then
	            if [0,4].include? encode.to_i then # FIXME: 2 always ASCII
	              begin
	                message = Iconv.new('ascii//ignore', 'utf-16be').iconv(message)
	                # Utility.log_msg "read_sms: decoded #{message}"
	              rescue Exception => e
	                Utility.log_err "read_sms: #{e.message}"
	              end
	            end
	          end	          
	          parameters['message'] = message
            parameters['service_time'] = parameters['service_time'].to_time
            parameters['status'] = 'INBOX'
          end
        
        when 'list_sms'
          if @pdu_mode && @also_read_when_list then # EXPERIMENTAL MODE ON GSM
            # see above 'read_sms'
            pdu_info = PDU.read(parameters['data'], parameters['length_pdu'].to_i)
            parameters['message'] = pdu_info['message']
            parameters['service_time'] = pdu_info['service_time']
            parameters['number'] = pdu_info['number']
            # save pdu info for pdu-log
            parameters['pdu_info'] = pdu_info
            parameters['status'] = case parameters['status'].to_i
              when 2 #STO UNSENT
                'DRAFT'
              when 3 #STO SENT
                'SENT'
              else #0:REC UNREAD,1:REC READ
                'INBOX'
              end
          end
          
      end
      parameters
    end
    
    # Change parameters before parse notify.
    def param_for_notify(function_name, parameters)
      case function_name
        when 'sms_status_report'
          if @pdu_mode then
            pdu_info = PDU.read(parameters['data'], parameters['length_pdu'].to_i)
            parameters['status_report'] = pdu_info['status_report']
            parameters['message_ref'] = pdu_info['message_ref']
            parameters['service_time'] = pdu_info['service_time']
            parameters['time'] = pdu_info['discharge_time']
            parameters['pdu_info'] = pdu_info
          else
            parameters['service_time'] = parameters['service_time'].to_time
            parameters['time'] = parameters['time'].to_time
          end
      end
      parameters
    end
    
    # Event handler on notify.
    def on_notify(function_name, x)
      x[2] = param_for_notify(function_name, x[2])
      case function_name
        when 'sms_status_report'
          x[2]['status'] = x[2]['status_report'].to_i == 
            (@pdu_mode ? 0 : 32768) ? 'SENT' : 'UNSENT'
          
          if !@sm_process.nil? && @sm_process['message_ref'] == x[2]['message_ref'] then
            inbox { |box| box.push( {'type' => 'status', 'data' => @sm_process.update(x[2])} ) }
            @sm_process = nil
          else                         
            inbox { |box| box.push( {'type' => 'status', 'data' => x[2].update( x[2] )} ) }
            @sm_process = nil # FIXME: i just add this!
          end   
          Utility.log_sms 'STAT', "(#{x[2]['message_ref']}) #{x[2]['status']} " + x[2]['service_time'].strftime('%Y-%m-%d %H:%M:%S'), '', @modem_device.device
          
        when 'ring_in', 'RING'
          #mail = outbox { |box| box.first } 
          #wait_hang_up = (!mail.nil? && mail['type'] == 'hang_up') ? true : false
          #if !wait_hang_up   # @ring_in_hang_up.nil?                                    
          #  outbox { |box| box.unshift({'type' => 'hang_up'}) } 
            @ring_in_hang_up = true
            Utility.log_msg "Ring In", @modem_device.device 
          #end
        when 'caller_id'
          #if @ring_in_hang_up == true then
          #  @ring_in_hang_up = x[2]['number']
            Utility.log_msg "Caller ID: #{x[2]['number']}", @modem_device.device
          #end          
      end
    end
    
    # Event handler on result.
    def on_result(function_name, parameters, x)
      x[2] = param_for_result(function_name, x[2])
      case function_name
        when 'list_sms'
          if @pdu_mode && @also_read_when_list then # EXPERIMENTAL MODE ON GSM
            # for saving time, also fetch
            # no different pdu when list_sms and read_sms, so do it now
            inbox { |box| box.push( {'type' => 'deliver', 'data' => x[2] } ) }
            Utility.log_sms 'RECV', "#{x[2]['number']} (#{x[2]['index']})", x[2]['message'], @modem_device.device         
            @sm_incomes[ x[2]['index'].to_i ] = true   # fetched
          else
            # just store the index, and tell not fetched
            # in text mode, complete information retrive via read_sms
            @sm_incomes[ x[2]['index'].to_i ] = false   # not fetched
          end
        when 'read_sms'
          inbox { |box| box.push( {'type' => 'deliver', 'data' => x[2].update( 
            { 'index' => parameters['index']}) } ) }
          # 'index' got from command parameter, bcoz result don't have index
          Utility.log_sms 'RECV', "#{x[2]['number']} (#{x[2]['index']})", x[2]['message'], @modem_device.device
        when 'send_sms'
          inbox { |box| box.push( {'type' => 'status', 'data' => @sm_process.update({'status' => 'SENDING', 'message_ref' => x[2]['message_ref']})} ) }
          trial = @sm_process['trial'] || ''
          Utility.log_sms 'SEND', "#{@sm_process['number']} (#{@sm_process['message_ref']}) [#{trial}]", @sm_process['message'], @modem_device.device
        when 'signal_quality'
          inbox { |box| box.push( {'type' => 'others', 'data' => {'signal_quality' => x[2]['rssi'].to_i}} )}          
          Utility.log_msg "Signal Quality: #{x[2]['rssi']}", @modem_device.device
      end
    end
    
    # Event handler on error.
    def on_error(function_name, parameters, x)
      case function_name
        when 'send_sms'
          inbox { |box| box.push( {'type' => 'status', 'data' => @sm_process.update({'status' => 'FAIL'})} ) }
          @sm_process = nil
          Utility.log_err "Fail send SMS, invalid parameters", @modem_device.device          
        else
          Utility.log_err "Error: #{function_name}, #{x[1]}", @modem_device.device
      end      
      false
    end
    
    # Event handler on ok.
    def on_ok(function_name, parameters, x)
      case function_name
        when 'delete_sms'
          Utility.log_msg "Delete SMS in modem (#{parameters['index']})", @modem_device.device
          @sm_incomes.delete(parameters['index']) # clear in sm_incomes, index should be to_i
      end
      true
    end
  end

end
