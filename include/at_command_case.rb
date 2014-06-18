# This file is part of Rametook 0.4
module Rametook

class AtCommandCase
  # Initialize then compile format string and case
  # [+format+] String for format case
  def initialize(format)
    compile(format)
  end 
  
  # Match parameters with case. Return +true+ if match
  # [+params+] Hash of AT parameters
  def match(params)
    return false if @case_field.nil?
    return false if params[@case_field].nil?
    !params[@case_field].scan(@case_regexp).empty?
  end
    
  private
    def compile(format)      
      if !format.nil? then
        @case_field, regx = format.scan(/(.*?)=(.*)/)[0]
        @case_regexp = Regexp.new('^' + regx + '$', Regexp::IGNORECASE)
      else
        @case_field = nil
        @case_regexp = nil
      end
    end

end

end # :end: Rametook
