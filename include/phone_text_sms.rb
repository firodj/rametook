module Rametook
module PhoneTextSms
  
  def format_status_list_sms(index)
    Phone::LIST_STATUSES[index]
  end
  
  def format_read_sms(params)
    message = params['data']
    unless (encode = params['encode']).nil? then
      if [0,4].include? encode.to_i then # FIXME: 2 always ASCII
        begin
          message = Iconv.new('ascii//ignore', 'utf-16be').iconv(message)
          # Utility.log_msg "read_sms: decoded #{message}"
        rescue Exception => e
          Utility.log_err "read_sms: #{e.message}"
        end
      end
    end	

    sms_message = {}
    sms_message['message'] = message
    sms_message['service_center_time'] = params['service_center_time'].to_sms_time if params['service_center_time']
    sms_message['number'] = params['number']
    sms_message['status'] = case params['status']
      when 'STO UNSENT'
        'UNSENT'
      when 'STO SENT'
        'SENT'
      else #0:REC UNREAD,1:REC READ
        'RECEIVED'
      end
      
    sms_message
  end
  
  def format_list_sms(params)
    sms_message = format_read_sms(params)
    sms_message['index'] = params['index'].to_i
    sms_message
  end
  
  def format_send_sms(sms_message)
    params = {}
    params['number'] = sms_message['number']
    params['reply'] = 1
    params['data'] = sms_message['message']
    params
  end
  
  def format_status_report_sms(params)
    stat_message = {}
    stat_message['message_ref'] = params['message_ref'].to_i
    stat_message['number'] = params['number']
    stat_message['service_center_time'] = params['service_center_time'].to_sms_time
    stat_message['discharge_time'] = params['discharge_time'].to_sms_time
    stat_message['status'] = params['status_report'].to_i == 32768 ? 'SENT' : 'SENT-FAILED'
    stat_message
  end
  
end

Phone.add_sms_mode 'TEXT', PhoneTextSms
end

