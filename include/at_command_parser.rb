# This file is part of Rametook 0.4

module Rametook

# This class hold many AtCommandFormats according to their case.
# Sometimes, an AT command can have different format that is determine
# by one or more of parameters' value.
class AtCommandParser
  attr_reader :name
  attr_reader :type
  attr_reader :function
  
  # Initialize new AtCommandParser.
  # [+name+] String ModemAtCommand's +name+
  # [+type+] String ModemAtCommand's +at_type+ (informatif only)
  def initialize(name, type, function)
    @name = name
    @type = type
    @function = function
    @formats = {nil => [AtCommandCase.new(nil), AtCommandFormat.new(nil)]} #
  end
  
  # Add modem format and its case when should this format will be used
  # [+cse+] String of ModemAtCommand's +case_format+
  # [+fmt+] String of ModemAtCommand's +format+
  def add_case_and_format(case_fmt,format)
    case_fmt = nil if !case_fmt.nil? && case_fmt.strip.empty?
    @formats[case_fmt] = [AtCommandCase.new(case_fmt), AtCommandFormat.new(format)]
  end
  
  # Parse AT code result parameters. Extended parameters (String
  # after line-feed) will be used if the AT code have data. This method
  # will select appropriate format according to case.
  # [+str+] String that is AT parameters
  # [+ext+] String after AT parameters (after line-feed)
  def parse(str, ext)
    at_format_def = @formats[nil][1]
    return if at_format_def.nil?
    
    # parse parameters
    params = at_format_def.parse(str, ext)

    # check if it have other format depend on parameters
    if @formats.size > 1 then
      @formats.each_pair {|case_fmt, at_case_and_at_format|
        at_case = at_case_and_at_format[0]
        at_format = at_case_and_at_format[1]
        
        next if at_format == at_format_def
        next if !at_case.match(params)
        
        params = at_format.parse(str, ext)
        return params
      }
      return # dont have sutiable case
    else 
      return params # just this, don't have onther format 
    end
  end

  # Make AT code command. This method will use approriate format according
  # to case.
  # [+params+] Hash of AT parameters.
  def create(params = {})
    # raise 'at-cmd-parser: last command not final' if wait_final?
    # @cmd = @@cmd[id] || @@cmd[0]
    str_seqs = nil
    if @formats.size > 0 then
      at_format_def = @formats[nil][1]
      @formats.each { |case_fmt, at_case_and_at_format|
        at_case = at_case_and_at_format[0]
        at_format = at_case_and_at_format[1]
        
        next if at_format == at_format_def
        next if !at_case.match(params)

        str_seqs = at_format.create(params)
        break
      }
      str_seqs = at_format_def.create(params) if str_seqs.nil? && !at_format_def.nil?
      return if str_seqs.nil?
    end
    
    # as: @name + ( str_seqs.nil? || str_seqs.empty? ? '' : '=' + str_seqs.to_s)
    if str_seqs.nil? || str_seqs.empty? then
      [ @name ]
    else
      str_seqs.first.insert(0, @name + '=')
      str_seqs
    end
    
  end

end

end
