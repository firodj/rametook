require RAMETOOK_PATH + '/include/pdu.rb'  

module Rametook
module PhonePduSms
  
  def format_status_list_sms(index)
    index
  end
  
  def format_read_sms(params)
    pdu_info = PDU.read( params['data'], params['length_pdu'].to_i)
    sms_message = {'pdu_info' => pdu_info } # save pdu info for pdu-log
    sms_message['log'] = params['length_pdu'].to_s + ' ' + params['data']
    
    sms_message['message'] = pdu_info['message']
    sms_message['service_center_time'] = pdu_info['service_center_time']
    sms_message['number'] = pdu_info['number']        
    sms_message['status'] = case params['status'].to_i
      when 2 #STO UNSENT
        'UNSENT'
      when 3 #STO SENT
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
    pdu_info = { 'first_octet' => ['sms-submit', 'v-rel', 'tp-srr'], 
		  'message_ref' => 00,
		  'number' => sms_message['number'],
		  'validity_period' => 0xAA,
		  'message' => sms_message['message'] }
			  
		params = {'pdu_info' => pdu_info} # save pdu info for pdu-log
    params['data'], params['length_pdu'] = PDU.write( pdu_info )
    
    params['log'] = params['length_pdu'].to_s + ' ' + params['data']
    params
  end
  
  def format_status_report_sms(params)
    pdu_info = PDU.read(params['data'], params['length_pdu'].to_i)
    stat_message = {'pdu_info' => pdu_info}
    stat_message['log'] = params['length_pdu'].to_s + ' ' + params['data']
    
    stat_message['message_ref'] = pdu_info['message_ref'].to_i
    stat_message['number'] = pdu_info['number']
    stat_message['service_center_time'] = pdu_info['service_center_time']
    stat_message['discharge_time'] = pdu_info['discharge_time']            
    stat_message['status'] = pdu_info['status_report'].to_i == 0 ? 'SENT-DELIVERED' : 'SENT-FAILED'
    
    stat_message
  end
end

Phone.add_sms_mode 'PDU', PhonePduSms
end
