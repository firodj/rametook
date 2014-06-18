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

  # This class is main loop that intializing and controlling some
  # device spoolers
  class MainSpooler
    
    # Start gateway and become main loop. This singleton method perform:
    def self.start(options = {})
      @@dir = options[:dir]
      @@name = options[:name]
      @@hostname = options[:hostname]      
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
      
      # Set trap signal
      Utility.log_msg "Trapping signal"
      term_trap = Proc.new { alert_devices }
      trap "INT", term_trap    # Ctrl-C trap
      trap "TERM", term_trap
      trap "TSTP", "IGNORE"	# Ctrl-Z trap
      
      # Establishing connection 
      Database.establish
         
      # Read configuration
      modem_devices = ModemDevice.find(:all, :conditions => ['active = ? AND hostname = ?', 1, @@hostname])
      if modem_devices.empty? then
        Utility.log_msg "No active device for this hostname."
        return
      end    
  
      # Setup device spooler 
      Utility.log_msg "Setup device spooler"
      
      @@modem_queue = []
      modem_devices.each { |modem_device| 
        @@devices[modem_device.id] = DeviceSpooler.new( modem_device )
        @@modem_queue << modem_device.id
      }
    end
    
    # - main loop
    # - managing sms-es within database and device-spooler
    def self.main      
      Utility.log_msg "Run device's spoolers and main spooler."      
      reconnect_db = false
      
      # == STDOUT DETACHED ==
      if SmsGateway::Rametook.daemonize then
        reconnect_db = true
      end      
                  
      Utility.sms_logger_open("#{@@dir}/#{@@name}")
      fail_count = 0
      
      # do main-spooler
      while true do
        # ReConnect to DB
        if reconnect_db then
          SmsGateway::Database.establish
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
	        @@devices.each { |device_id, device|
	          device.run if device.restart
	        }
	      end
                
        time_now = Time.now
        
        # check messages to send
        short_messages = []
        
        begin
          if !@@terminate then
            short_messages += ModemShortMessage.find(:all, :conditions => ['status = ?', 'OUTBOX'])
            short_messages += ModemShortMessage.find(:all, :conditions => ['status = ? OR status = ?', 'UNSENT', 'RESEND'])
            short_messages += ModemShortMessage.find(:all, :conditions => ['status = ?', 'WAITING']) #FIXME: change to WAIT
          end
        rescue Exception => e  # ActiveRecord::ActiveRecordError, Errno::ECONNREFUSED
          Utility.log_err "Failed to query OUTBOX: #{e.message}"
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
            device = @@devices[device_id]
            next if device.nil? || !device.ready?
 
            begin
              skip_this = false
              if short_message.status == 'WAITING' then
                if (time_now - short_message.waiting_time > 60.0) then
                  short_message.status = 'UNSENT'
                else
                  skip_this = true                  
                end
              end
              if short_message.status == 'UNSENT' then
                short_message.status == 'RESEND'
                short_message.trial = (short_message.trial || 0) + 1
                if short_message.trial > 3 then
                  short_message.trial  = 3
                  short_message.status = 'FAIL' 
                  skip_this = true
                end              
              else
                short_message.modem_device_id = device_id
              end

              skip_this = true if device.number_outbox_submit >= 1

              short_message.status = 'PROCESS' if !skip_this
              short_message.save
              next if skip_this
            rescue Exception => e
              Utility.log_err "Failed to update PROCESS: #{e.message}"
              reconnect_db = true
            else
              sm = short_message.to_hash.update({'reply' => 1})
              device.outbox { |box| box.push( {'type' => 'submit', 'data' => sm} ) }
            end

            # skip send sms if terminate
            break if @@terminate
          }
        end
        
        # get received message, and process all device
        device_ready = 0
        device_running = 0
        @@devices.each { |device_id, device|          
          device_ready += 1 if device.ready?
          device_running += 1 if device.running?
          
          # skip received from not ready device
          next if !device.ready?
          
          # get from device thread
          while !(mail = device.inbox { |box| box.shift }).nil? do
            begin
              if mail['type'] == 'deliver' then              
                short_message = ModemShortMessage.new(:modem_device_id => device_id)
                short_message.from_hash mail['data']
                short_message.save
                
                # store PDU for DEBUG
                if mail['data']['pdu_info'] then
                  pdu_log = ModemPduLog.new(:modem_short_message_id => short_message.id)                  
                  pdu_log.length_pdu = mail['data']['length_pdu']
                  pdu_log.pdu = mail['data']['data']
                  pdu_log.first_octet = mail['data']['pdu_info']['first_octet'].join(', ')
                  pdu_log.data_coding = mail['data']['pdu_info']['data_coding'].join(', ')
                  pdu_log.udh = mail['data']['pdu_info']['user_header']
                  pdu_log.save
                end
                    
                # delete delivered mail on phone                
                device.outbox { |box| box.unshift({'type' => 'destroy', 'data' => mail['data']}) }
              elsif mail['type'] == 'status' then
                short_message = if !mail['data']['id'].nil? then
                  ModemShortMessage.find(:first, :conditions => ['id = ?', mail['data']['id'].to_i])
                else
                  ModemShortMessage.find(:first, :conditions => ['message_ref = ? AND modem_device_id = ?', mail['data']['message_ref'], device_id])
                end
                
                if !short_message.nil? then
                  short_message.message_ref = mail['data']['message_ref']
                  short_message.status      = mail['data']['status']
                  short_message.time        = mail['data']['time']
                  short_message.service_time = mail['data']['service_time']
                  short_message.waiting_time = time_now if short_message.status == 'WAITING'
                  short_message.save
                  
                  # store PDU for DEBUG
                  if ['SENDING','SENT'].include?(short_message.status) && mail['data']['pdu_info'] then
                    pdu_log = ModemPduLog.new(:modem_short_message_id => short_message.id)                  
                    pdu_log.length_pdu = mail['data']['length_pdu']
                    pdu_log.pdu = mail['data']['data']
                    pdu_log.first_octet = mail['data']['pdu_info']['first_octet'].join(', ')
                    pdu_log.data_coding = mail['data']['pdu_info']['data_coding'].join(', ') if mail['data']['pdu_info']['data_coding']
                    pdu_log.save
                  end
                
                end
              elsif mail['type'] == 'others' then
                modem_device = ModemDevice.find(:first, :conditions => {:id => device_id})
                modem_device.update_attributes( 
                  mail['data'].update( {'last_refresh' => time_now} )
                ) unless modem_device.nil?
              end            
            rescue Exception => e            
              device.inbox { |box| box.unshift mail } 
              Utility.log_err "Failed to save INBOX: #{e.message}"
              reconnect_db = true
              break
            end
          end
          
          if @@terminate
            # tell device to exit from loop if device must be terminated
            device.ready_to_stop if device.empty_box? && device.terminating?
          end
        }        
        
        # wait or exit loop if terminate
        if @@terminate
          break if device_ready == 0 && device_running == 0
        else
          sleep(2) 
        end
      end
      
      Utility.sms_logger_close
      Utility.log_msg "Done."
    end
    
    # Alert device spoolers to end their job
    def self.alert_devices
      return if @@terminate
      
      Utility.log_msg "Terminating..."

      # Stop device-spooler
      @@devices.each { |device_id, device|
        device.stop
      }
      @@terminate = true
    end  
   
  end
end
