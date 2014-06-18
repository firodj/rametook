# This file is part of Rametook 0.3.6 (in transition)

module Rametook

# This class is device spooler that communicate with modem.
class DeviceSpooler
  attr_reader :device_tasks
  attr_reader :main_tasks
  attr_reader :restart
  
  # thread safe
  def initialize( modem_device )
    @terminate = false
    @request_to_terminate = false
    @thread    = nil      
    @restart   = true
    @ready     = false # gateway ready
      
    @device_tasks  = TaskQueue.new
    @main_tasks = TaskQueue.new
     
    @sms_incomes = {}
    @sms_process = nil
    @hang_up_call = false
    
    @max_inbox = 20
    @min_inbox = 5   
    @read_priority = false
    
    @phone = Phone.new( modem_device )
    
    @capable_of = {}
    @phone.modem_device.capabilities.split(',').each { |capability|
      c_name, c_value = capability.split(':')
      c_name = c_name.strip.gsub(' ','_').to_sym
      @capable_of[c_name] = c_value ? c_value.strip : true
    } if @phone.modem_device.capabilities
  end
  
  def capable_of(name)
    @capable_of[name]
  end
  
  def modem_device
    @phone.modem_device
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
  
  # Send stop signal to device spoooler for finalize all jobs.
  def stop      
    @request_to_terminate = true if running?
  end    

  # This method will tell device spooler to exit loop.
  def ready_to_stop
    @ready = false
  end
  
  # Return true if inbox and outbox are empty (indicate device don't hv job)
  def tasks_empty?
    (@device_tasks.size + @main_tasks.size) == 0
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

    return false unless @phone.open
    
    @phone.clean_serial_buffer
    unless @phone.start_and_detect then
      @phone.close
      
      @main_tasks.add( TaskItem.update_device_info( {
        :identifier => @phone.identifier,
        :modem_type_id => nil } ) )
      
      return false      
    end
    
    # save info to db
    @main_tasks.add( TaskItem.update_device_info( {
      :identifier => @phone.identifier,
      :modem_type_id => @phone.modem_type.id } ) )
      
    @phone.write_init_commands

    @thread = Thread.new {
      check_count = 0
      
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
          process_unsolicited
          
          # Check signal quality          
          check_signal_quality if check_count == 0
          
          check_count = (check_count + 1) % 5
          
          # Wait a little to save CPU
          if w_r && w_t then
            sleep(2)
          end
        end		            
      end
      
      @ready = false       
      @phone.close
      @terminate = false
      Utility.log_msg "End.", @phone.modem_device.device
    }        
  end
  
  # Accept terminate if terminate has been requested
  def accept_terminate
    if @request_to_terminate then
      Utility.log_msg "Terminating signal received.", @phone.modem_device.device
      @terminate = true 
      @request_to_terminate = false
    end
  end
  
  def transmit_sms
    workless = true
    pending_task = []
    while task_item = @device_tasks.current do
      workless = false
      case task_item.task
        when :send_sms
          if @read_priority || (capable_of(:wait_status_report) && @sms_process) then 
            # don't sent now, push again
            # FIXME: possible unnecessary mail loop-back in mail and
            #        uninfinite loop.
            
            @device_tasks.pending
          else
            task_item = @device_tasks.pull
            
            sms_message = task_item.sms_message
            sms_message['status'] = 'SENT'
            if message_ref = @phone.send_sms(sms_message['number'], sms_message['message'], sms_message) then
              
              if message_ref >= 0 then
                sms_message['message_ref'] = message_ref
                @sms_process = sms_message     
              else
                if capable_of(:dont_care_message_ref) then
                  @sms_process = sms_message
                else
                  sms_message['status'] = 'SEND-ERROR'
                end
              end
            else
              sms_message['status'] = 'SEND-ERROR'
            end
            @main_tasks.add( TaskItem.update_status_sms(sms_message) )
          end
          
        when :delete_sms
          task_item = @device_tasks.pull
          
          index = task_item.sms_message['index'].to_i
          
          Utility.log_msg "Delete SMS in modem [#{index}]", @phone.modem_device.device
          
          #  don delete exacly :D
          # TEST:  turn off delete_sms
          if @phone.delete_sms(index) then
            @sms_incomes.delete(index)
          end
          
          if @read_priority && @sms_incomes.size <= @min_inbox then               
            @read_priority = false 
            Utility.log_msg "Read priority disable!, #{@sms_incomes.size} SMS to read", @phone.modem_device.device
          end
          
        else # dont know what is this just pull out
          task_item = @device_tasks.pull
      end     
    end

    @device_tasks.append
    
    workless
  end
    
  def list_incoming_sms
    if @sms_incomes.empty? then
      read_when_listing = capable_of(:read_when_listing)
      
      sms_messages = @phone.list_sms('ALL', read_when_listing)
      
      return false unless sms_messages
      
      sms_messages.each { |sms_message|
        if read_when_listing then
          @main_tasks.add( TaskItem.read_sms(sms_message) )
          @sms_incomes[ sms_message['index'].to_i ] = true
        else
          @sms_incomes[ sms_message['index'].to_i ] = false
        end
      }
    
      Utility.log_msg "Incoming #{@sms_incomes.size} SMS", @phone.modem_device.device if @sms_incomes.size > 0
      
      if @sms_incomes.size >= @max_inbox then
        @read_priority = true 
        Utility.log_msg "Read priority enabled!", @phone.modem_device.device
      end        
    end  
  end
  
  # Receive messages to inbox.
  def receive_sms
    workless = true

    list_incoming_sms

    @sms_incomes.each { |index, fetched|
      next if fetched
      
      workless = false
      
      @sms_incomes[index] = true
      sms_message = @phone.read_sms(index)
      sms_message['index'] = index

      @main_tasks.add( TaskItem.read_sms(sms_message) )

      break
    }

    workless
  end

  # Check signal quality.
  def check_signal_quality
    rssi_signal = @phone.signal_quality
    @main_tasks.add( TaskItem.update_device_info(:signal_quality => rssi_signal) )
    Utility.log_msg "Signal Quality: #{rssi_signal}", @phone.modem_device.device
  end

  def process_unsolicited
    @phone.process_pending_unsolics { |function, params, result|
      case function
        when :ring_in
          @hang_up_call = true     
    
        when :caller_id
        
        when :sms_status_report
          stat_message = result
          if !@sms_process.nil? && @sms_process['message_ref'] == 
            stat_message['message_ref'] then
            sms_message = @sms_process.update(stat_message)
            @main_tasks.add( TaskItem.update_status_sms(sms_message) )            
          else
            @main_tasks.add( TaskItem.update_status_sms(stat_message) )
          end
          
          @sms_process = nil
      end 
    }
    
    if @hang_up_call then        
      @hang_up_call = false
      @phone.hang_up
    end
    
  end
  
end

end
