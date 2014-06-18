# This file is part of Rametook 0.4

module Rametook

class TaskItem
  attr_reader :task
  attr_reader :sms_message
  attr_reader :device_info
  
  def initialize(task, options = {})
    @task = task
    @sms_message = options[:sms_message]
    @device_info = options[:device_info]
  end
  
  # device-spooler's task
  def self.send_sms(sms_message)
    new(:send_sms, {:sms_message => sms_message})
  end
  
  # device-spooler's task
  def self.delete_sms(sms_message)
    new(:delete_sms, {:sms_message => sms_message})
  end
  
  # main-spooler's task
  def self.read_sms(sms_message)
    new(:read_sms, {:sms_message => sms_message})
  end
  
  # main-spooler's task
  def self.update_status_sms(sms_message)
    new(:update_status_sms, {:sms_message => sms_message})
  end
  
  # main-spooler's task
  def self.update_device_info(device_info)
    new(:update_device_info, {:device_info => device_info})
  end
  
end

end # :end: Rametook
