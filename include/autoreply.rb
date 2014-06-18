# This file is part of Rametook 0.3.6 (in transition)

module Rametook

class AutoReply

=begin
  @@thread = nil
  @@terminate = false
  
  def self.stop
    @@terminate = true
  end
  
  # Return true if thread is still running (alive).
  def self.running?
    return false if @@thread.nil?
    return @@thread.alive?
  end
  
  def self.terminating?
    return @@terminate
  end
    
  def self.run
    return if @@thread
    
    @@thread = Thread.new {
      Utility.log_msg "Auto-reply - Started."
      
      @@terminate = false
      while !@@terminate do
        Utility.log_msg "Auto-reply - Trigger!"
        clean
        parse
        
        wait_time = 10
        while wait_time > 0 && !@@terminate do
          sleep(1)
          wait_time -= 1
        end
      end
      @@terminate = false
      
      Utility.log_msg "Auto-reply - Stopped."
    }
  end
=end
  
  # clean Sent and Fail
  # DEPRECATED
  def self.clean
=begin
    time_now = Time.now
    sms_removes = []
    short_messages = []
    short_messages += ModemShortMessage.find_by_status 'SENT'
    short_messages += ModemShortMessage.find_by_status 'FAIL'
    short_messages.each { |sm|
      sms_removes << sm.id
      log = sm.trial.nil? ? nil : "Trial #{sm.trial} times"
      sm_log = SmsLog.create(:number => sm.number,
        :message => sm.message, :status => sm.status, 
        :service_center_time => sm.service_center_time, 
        :check_time => time_now,
        :short_message_id => sm.id, :process => log)
        
      # sms_outbox = SmsOutbox.create( :number => sm.number, :message => sm.message, :sent_time => time_now )
    }
    
    if sms_removes.size > 0 then
      Utility.log_msg "Auto-reply: Clean #{sms_removes.size} Sent/Fail Messages"
    end
    
    ModemShortMessage.delete(sms_removes)
=end
  end
  
  # parse, should be received, not partial
  def self.parse
    sms_inboxes = SmsInbox.acquire_received_short_messages
    
    begin
      sms_processed = SmsInbox.process_unprocess_inbox
    rescue Exception => e
      Utility.log_msg "Auto-reply exception: #{e.message}, #{e.backtrace.first}."
    end

    if sms_inboxes.size > 0 then
      Utility.log_msg "Auto-reply: Saving #{sms_inboxes.size} Inbox Messages"
    end
    if sms_processed.size > 0 then
      Utility.log_msg "Auto-reply: Processing #{sms_inboxes.size} Inbox Messages"
    end
  end
    
end

end # :end: Rametook
