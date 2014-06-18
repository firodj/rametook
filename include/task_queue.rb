# This file is part of Rametook 0.4

require RAMETOOK_PATH + '/include/task_item.rb'

module Rametook

class TaskQueue
  def initialize
    @mutex = Mutex.new
    @queue = []
    @pending_queue = []
  end
  
  def pull
    return_value = nil
    @mutex.synchronize { return_value = @queue.shift }
    return_value
  end
  
  def current
    return_value = nil
    @mutex.synchronize { return_value = @queue.first }
    return_value
  end
  
  def pending
    return_value = nil
    @mutex.synchronize { 
      return_value = @queue.shift
      @pending_queue << return_value if return_value
    }
    return_value
  end
  
  def add(item)
    @mutex.synchronize { @queue.push(item) }
  end
  
  def size(task = nil)
    return_value = nil
    @mutex.synchronize { return_value = queues_size(task) }
    return_value
  end
  
  def append(queue = nil)
    return_value = nil
    
    @mutex.synchronize {
      queue ||= @pending_queue
      @queue += queue
      queue.clear
      return_value = queues_size
    }
    return_value
  end
  
  private
    def queues_size(task = nil)
      if task then
        @queue.size + @pending_queue.size
      else
        @queue.inject(0) { |s,item| item.task == task ? s + 1 : s } +
        @pending_queue.inject(0) { |s,item| item.task == task ? s + 1 : s }
      end
    end
end

end # :end: Rametook
