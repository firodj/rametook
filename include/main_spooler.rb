# This file is part of Rametook 0.3.6 (in transition)

module Rametook

# This class is main loop that intializing and controlling some
# device spoolers
class MainSpooler
  
  # Start gateway and become main loop. This singleton method perform:
  def self.start(options = {})
    @@dir = options[:dir]
    @@name = options[:name]
    #@@hostname = options[:hostname]      
    @@cmd = options[:cmd]
    
    init
    main
  end
  
  # - establishing database connection
  # - read modem configuration
  # - set traps for abort-signal
  # - init and run device-spoolers (modems)    
  def self.init
    Thread.abort_on_exception = true # debug
    
    @@terminate = false     
    @@devices = {}
    @@device_spoolers = {}
    
    # Set trap signal
    Utility.log_msg "Trapping signal"
    term_trap = Proc.new { alert_devices }
    trap "INT", term_trap    # Ctrl-C trap
    trap "TERM", term_trap

    if RAMETOOK_OS == 'linux' then
      trap "TSTP", "IGNORE"	# Ctrl-Z trap
    end

    # Establishing connection 
    #Database.establish
    
    ModemErrorMessage.init_constants
    
    # Read configuration
    modem_devices = ModemDevice.find(:all, :conditions => {:active => true})
    
    # 'active = ? AND hostname = ?', 1, @@hostname]
    
    if modem_devices.empty? then
      Utility.log_msg "No active device." # for this hostname."
      return
    end    

    # Setup device spooler 
    Utility.log_msg "Setup device spooler"
    
    # Modem queue for send
    @@modem_queue = []
    
    modem_devices.each { |modem_device| 
      device_spooler = DeviceSpooler.new( modem_device )
      @@device_spoolers[modem_device.id] = device_spooler
      
      @@modem_queue << modem_device.id unless device_spooler.capable_of(:dont_send)
    }
  end
  
  # - main loop
  # - managing sms-es within database and device-spooler
  def self.main      
    Utility.log_msg "Run device's spoolers and main spooler."      
    reconnect_db = false
    
    # == STDOUT DETACHED ==

    if Rametook::Application.daemonize then
      reconnect_db = true
    end      
    
    Utility.sms_logger_open("#{@@dir}/log/#{@@name}")
    fail_count = 0

    # do main-spooler
    while true do
      # ReConnect to DB
      if reconnect_db then
        #Rametook::Database.establish
        #ActiveRecord::Base.establish_connection(@conn_spec)
        
        reconnect_db = false 
        fail_count += 1
        if fail_count > 3 then
          alert_devices # just shut down!
        else
          sleep(1)
        end
      end
      
      # Run device-spooler, if not run
      if !@@terminate then          
        @@device_spoolers.each { |modem_device_id, device_spooler|
          device_spooler.run if device_spooler.restart
        }
        ## AutoReply.run if !AutoReply.running?
      end
              
      time_now = Time.now
      
      # check messages to send
      short_messages = []
      
      begin
        if !@@terminate then
          short_messages += ModemShortMessage.find_by_status 'SEND'
        end
      rescue Exception => e  # ActiveRecord::ActiveRecordError, Errno::ECONNREFUSED
        Utility.log_err "Failed to query SEND: #{e.message}"
        reconnect_db = true       
      end

      if !short_messages.empty? then
        short_messages.each { |short_message|
          # add to deivce thread
          device_id = short_message.modem_device_id
          if device_id.nil? || device_id <= 0 then
            device_id = @@modem_queue.shift
            @@modem_queue.push device_id
          end
          device_spooler = @@device_spoolers[device_id]
          next if device_spooler.nil? || !device_spooler.ready?

          begin
            skip_this = false
=begin
            if short_message.status == 'WAITING' then
              if (time_now - short_message.waiting_time > 60.0) then
                short_message.status = 'UNSENT'
              else
                skip_this = true                  
              end
            end
=end

            short_message.lock!
            short_message.modem_device_id = device_id
            
            chgstat = false
            if device_spooler.device_tasks.size(:send_sms) >= 1 then
              skip_this = true
            elsif short_message.status == 'SEND' then
              short_message.status = 'SEND-PROCESS'
              chgstat = true
            end
            short_message.save!
            short_message.mark_status_invalid! if chgstat
            
            next if skip_this
          rescue Exception => e
            Utility.log_err "Failed to update SEND-PROCESS: #{e.message}"
            reconnect_db = true
          else
            device_spooler.device_tasks.add( TaskItem.send_sms(short_message.to_hash.update('reply' => 1)) )
          end

          # skip send sms if terminate
          break if @@terminate
        }
      end
      
      # get received message, and process all device
      device_ready = 0
      device_running = 0
      @@device_spoolers.each { |modem_device_id, device_spooler|
        
        device_ready += 1 if device_spooler.ready?
        device_running += 1 if device_spooler.running?
        
        # skip received from not ready device
        ##next if !device.ready?
        
        # get from device thread
              # mail = device.inbox { |box| box.shift }
        while task_item = device_spooler.main_tasks.pull do
          
          case task_item.task
            when :read_sms
              sms_message = task_item.sms_message
              
              short_message = ModemShortMessage.new(:modem_device_id => modem_device_id)
              short_message.from_hash(sms_message)
              short_message.save
              
              # store PDU for DEBUG
=begin
              if sms_message['pdu_info'] then
                pdu_log = ModemPduLog.new(:modem_short_message_id => short_message.id)                  
                pdu_log.length_pdu = sms_message['params']['length_pdu']
                pdu_log.pdu = sms_message['params']['data']
                
                pdu_log.first_octet = sms_message['pdu_info']['first_octet'].join(', ')
                pdu_log.data_coding = sms_message['pdu_info']['data_coding'].join(', ')
                pdu_log.udh = sms_message['pdu_info']['user_header']
                pdu_log.save
              end
=end
            
              # delete delivered mail on phone     
              device_spooler.device_tasks.add( TaskItem.delete_sms(sms_message) )           
              #device.outbox { |box| box.unshift({'type' => 'destroy', 'data' => mail['data']}) }
            when :update_status_sms
              stat_message = task_item.sms_message
              
              # maybe you can find short_message id
              short_message = nil
              if stat_message['id'] then
                short_message = ModemShortMessage.find(:first, :conditions => ['id = ?', stat_message['id'].to_i], :lock => true)
              else
                if stat_message['message_ref'] then
                  short_message = ModemShortMessage.find(:first, :conditions => ['message_ref = ? AND modem_device_id = ?', stat_message['message_ref'].to_i, modem_device_id], :lock => true)
                end
                
                # some modem don't use message_ref, so find by number
                unless short_message then
                  # 'SENDING'
                  short_message = ModemShortMessage.find(:first, 
                    :conditions => ["number = ? AND status IN ('SENT') AND modem_device_id = ?",  
                      stat_message['number'], modem_device_id],
                    :lock => true )
                end
              end
              
              #y stat_message
              
              # update short-message status
              if short_message then
                chgstat = short_message.status != stat_message['status']
                
                short_message.message_ref = stat_message['message_ref']
                short_message.status = stat_message['status']
                short_message.discharge_time = stat_message['discharge_time']
                short_message.service_center_time = stat_message['service_center_time']
                # short_message.waiting_time = time_now if short_message.status == 'WAITING'
                
                short_message.save!
                short_message.mark_status_invalid! if chgstat
              end
              
              # store PDU for DEBUG
=begin
              if stat_message['pdu_info'] then # && %w(SENDING SENT).include?(short_message.status)
                pdu_log = ModemPduLog.new(:modem_short_message_id => (short_message ? short_message.id : nil) )
                pdu_log.length_pdu = stat_message['params']['length_pdu']
                pdu_log.pdu = stat_message['params']['data']
                
                pdu_log.first_octet = stat_message['pdu_info']['first_octet'].join(', ')
                pdu_log.data_coding = stat_message['pdu_info']['data_coding'].join(', ') if stat_message['pdu_info']['data_coding']
                pdu_log.save                    
              end
=end
        
            when :update_device_info
              modem_device = ModemDevice.find(:first, :conditions => {:id => modem_device_id})
              modem_device.last_refresh = time_now
              modem_device.update_attributes(task_item.device_info)
              
          #rescue Exception => e            
          # device.inbox { |box| box.unshift mail } 
          #  Utility.log_err "Failed to save INBOX: #{e.message}"
          #  reconnect_db = true
          #  break
          
          end
        end
        
        if @@terminate then
          # tell device to exit from loop if device must be terminated
          device_spooler.ready_to_stop if device_spooler.tasks_empty? && device_spooler.terminating?
        end
      }        
      
      # auto reply
      ### deprecated: AutoReply.clean
      AutoReply.parse
      
      # wait or exit loop if terminate
      if @@terminate
        break if device_ready == 0 && device_running == 0    ## && !AutoReply.running?
      else
        sleep(2) 
      end
    end
    
    Utility.sms_logger_close
    Utility.log_msg "Done."
    
    ActiveRecord::Base.verify_active_connections!
  end
  
  # Alert device spoolers to end their job
  def self.alert_devices
    return if @@terminate
    
    Utility.log_msg "Terminating..."
        
    # Stop device-spooler
    @@device_spoolers.each { |modem_device_id, device_spooler|
      device_spooler.stop
    }
    @@terminate = true
  end  
 
end

end
