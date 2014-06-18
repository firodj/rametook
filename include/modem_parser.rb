# This file is part of Rametook 0.4

require RAMETOOK_PATH + '/include/at_command_format.rb'
require RAMETOOK_PATH + '/include/at_command_case.rb'
require RAMETOOK_PATH + '/include/at_command_parser.rb'

module Rametook

ModemResponse = Struct.new(:type, :name, :params, :function, :last_command)

# Each Modem (defined in ModemType record) has one ModemParser object.
# ModemParser object hold many ModemAtCommand records for specified ModemType.
# Every ModemAtCommand will be grouped into its <tt>at_type</tt> and 
# <tt>name</tt> and then saved to one AtCommandParser object.
#
# === AT Code Type
# 1. Unsolicited (<tt>UNSOLIC</tt>). 
#    This AT code send by modem to PC (result) as a <em>notification</em>, 
#    and not a response to an executed AT command. This AT code can be found 
#    anytime except between AT command's reponse.
#    ex: result code when receive incoming call.
# 2. Command (<tt>COMMAND</tt>).
#    This AT code send to modem by PC (command) to <em>instruct</em> modem
#    to perform an action. ex: command to dial a number.
# 3. Result (<tt>RESULT</tt>).
#    This AT code send by modem to PC (result) as <em>response</em> to an 
#    executed AT command. It has specified format according to an executed
#    AT command. Not all AT command have specified response. This AT code
#    must be found before final response.
# 4. Final (<tt>FINAL</tt>).
#    This AT code send by modem to PC (result) as a final response to executed
#    AT command that execution has been completed. No other executed AT command
#    response after this final response. ex: <tt>OK</tt> after executed command 
#    is success, or <tt>ERROR</tt> after executed wrong command.
#
#
class ModemParser
  attr_reader :parsers
  #attr_reader :responses
  attr_reader :got_prompt
  attr_reader :last_cmdfin # Get final response from last executed command.
  
  attr_reader :results
  attr_reader :unsolics
  
  # Initialize Modem object.
  def initialize(modem_type)
    @buffer = ''    # result buffer that not yet processed
    @cmd_name = nil # current command-name, and tell AT command that response is waited
    @cmd_atcommand = [] # current pending at command for @cmd_name, usually because prompt
    @got_prompt = false # cmd_prompt
    
    # TODO: deleted
    @responses = []  # unsoliciated results

    @unsolics = []    
    @results = []
    @final_result = nil
        
    @parsers = {
      'UNSOLIC'=>{},
      'RESULT'=>{},
      'FINAL'=>{},
      'COMMAND'=>{}
    }
    @last_cmdfin = nil # last successfull command, avaiable after get final
    
    # standard command, ATA, ATH
    #@parsers['COMMAND'].update( { 
    #  'H' => AtCommandParser.new('H','COMMAND'), #hang-up
    #  'A' => AtCommandParser.new('A','COMMAND')  #answer-call
    #} )
    # standard unsolicited, RING
    #@parsers['UNSOLIC'].update( {
    #  'RING' => AtCommandParser.new('RING','UNSOLIC') # ring-in
    #} )
    
    # create AT command parser from Modem Type
    for at_cmd in modem_type.modem_at_commands do
      add_at_commands( at_cmd.name, at_cmd.at_type, at_cmd.case_format, at_cmd.format, at_cmd.function_name)
    end
  end
  
  # [+modem_type+] ModemType model for specified modem's type
  def add_at_commands(name, type, case_format, format, function)
    @parsers[type] ||= {}
    @parsers[type][name] ||= AtCommandParser.new(name, type, function)
    at_parser = @parsers[type][name]
    at_parser.add_case_and_format(case_format, format)
  end
  
  # Return true if final response not yet received.
  def wait_final?
    !@cmd_name.nil?
  end
 
  # Return true if there is still atcommand to send (pauses because waiting prompt) 
  def wait_prompt?
    !@cmd_atcommand.empty?
  end

  # Build an AT command from given +name+ and +param+
  # [+name+] String for AT command's name.
  # [+param+] Hash for AT command's parameters.
  # Return a String of a line of AT command.
  def command(name, params = {})
    raise 'at-cmd-parser: last command not final' if wait_final?

    @cmd_name = name
    @final_result = @last_cmdfin = nil
    @results = []
    cmd = @parsers['COMMAND'][@cmd_name]

    @got_prompt = 0
    
    if !cmd.nil? then
      @cmd_atcommand = cmd.create(params)
      return 'AT' + @cmd_atcommand.shift
    else
      # just return command's name. ex: AT, ATE0, ATI0, etc..
      @cmd_atcommand = []
      return @cmd_name
    end
  end
  
  # return next AT command (pending prompt)
  def next_command
    return if !wait_prompt?
    @got_prompt -= 1
    return @cmd_atcommand.shift
  end

  # Retrive AT response by shifting out <tt>@responses</tt> array.
  def get_responses(&block) # :yields: respond
    if block.nil? then
      @responses.shift
    else 
      while !(response = @responses.shift).nil? do block.call(response) end      
    end
  end

  # Parse AT response then save it to <tt>@responses</tt> array.
  # [+str+] String of received AT response
  def parse(str='')
    #raise 'atc-cmd-parser: parse buffer nil' if @buffer.nil?
    
    @buffer << str
    return false if @buffer.empty?

    # only detect "\r\nOK\r\n", "\r\n+CSQ: bla..bla..\r\n",
    # or in cmda/text mode "\r\r\nOK\r\n".
    # but, how to detect prompt: "\r\n>\s"
    # /(.*?(\r\n)+)(.*?)(\r\n.*)/im
    
    regexp_rn_result_rn = /(.*?(\r\n)+)((.+?)(\r\n.*)|(>\s)(.*))/im
                        #       rn       c   ext      cprompt ext2
    
    scanned = @buffer.scan(regexp_rn_result_rn)
    pre,rn,grp,c,ext,cprompt,ext2 = scanned.first
    
    ###puts "buffer: #{@buffer.inspect}"
    
    # pre must be empty!
    # ext or ext2
    @buffer = ext || ext2 || ''
        
    ###puts "scanned: "
    
    # get name
    if !c.nil? then
      name,sp,strparam = c.scan(/([^\:]+)(\:?\s?)(.*)/im)[0]      
                       #          name    sp      strparam
      type = name.nil? ? 'STRING' : nil
      function = nil
      params = nil
    elsif !cprompt.nil? # get prompt
      type  = 'PROMPT'
      function = nil
      c = cprompt
      ext = ext2
    else
      return false
    end
    
    ###puts "c: #{c.inspect}"
    ###puts "ext: #{ext.inspect}"
    
    # check for unsolicited 1st, in case not prompt
    if @parsers['UNSOLIC'].has_key?(name) && params.nil? then
      at_parser = @parsers['UNSOLIC'][name]
      if params = at_parser.parse(strparam, ext) then
        function = at_parser.function
        type = 'UNSOLIC'
      end
    end

    #check for command response, in case not unsolicited
    if !@cmd_name.nil? && params.nil? then
      if type.nil? then
        if @parsers['RESULT'].has_key?(name) && @cmd_name == name then
          at_parser = @parsers['RESULT'][name]
          if params = at_parser.parse(strparam, ext) then
            type = 'RESULT' 
            function = at_parser.function
          end
          
        elsif @parsers['FINAL'].has_key?(name) then
          # end of AT command response
          at_parser = @parsers['FINAL'][name]
          if params = at_parser.parse(strparam, ext) then
            type = 'FINAL'             
            function = at_parser.function
            @final_result = @last_cmdfin = ModemResponse.new(type, name, params, function, @cmd_name ) 
            @cmd_name = nil 
          end          
          
        # should this work? TODO: delete me if all GSM don flow to this
        # elsif c == "> " # may be prompt (that skipped by other unsolic dll) 
        #   type = 'PROMPT'
        end
      end
      
      if type == 'PROMPT'then
        @got_prompt += 1
        name, params = c, {} 
      end
      
      type, name, params, function = 'STRING', c, {}, nil if params.nil?
    end
  
    # save mathcing params 
    if !params.nil? then
      ext = params.delete(0) if params.has_key?(0) #update ext, (after pars#match)

      response = ((type == 'FINAL') ? @final_result :
        ModemResponse.new(type, name, params, function, @cmd_name) )
    else
      response = ModemResponse.new(nil, c, nil, nil, nil) # :name => c
    end
    
    if %w(RESULT STRING FINAL).include?(response.type) then
      @results << response
    elsif response.type = 'UNSOLIC' then
      @unsolics << response
    else
      #   
    end
    
    # TODO: delete me:
    @responses << response
       
    @buffer = ext
    return true
  end
end

end
