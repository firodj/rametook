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

  # This class for parsing and build AT command from given format. The string
  # format and string case must be compiled first to RegExp.
  class AtCommandFormat

    # Special characters (escaped characters) that is used in format string
    # for nice editing
    SPECIAL_CHAR = {'CR' => "\r", 'LF' => "\n", 'CTRL-Z' => "\C-z", 'ESC' => "\e"}

    # Initialize then compile format string and case
    # [+cse+] String for case
    # [+fmt+] String for format
    def initialize(cse,fmt)
      compile(fmt)
      compile_case(cse)
    end      

    # Make AT command.
    # [+var+] Hash of parameters
    # If this command <tt>@has_data</tt>, this method will fill +length+ 
    # parameter with +data+ paramter size (String)
    def make(var)
      var['length'] = var['data'].size if @has_data && var['length'].nil?
      build(var)
    end
  
    # Match AT command by parsing.
    # [+str+] String of AT parameters
    # [+ext+] String of extended parameters
    def match(str, ext = '')  
      str_ext = @has_data ? str + ext : str

      s = str_ext.scan(@regexp)
      m = {}
      # get param 
      if !s[0].nil? then
        @var.each { |name,pos|
          m[name] = s[0][pos]
        }
      end
      # get data
      if @has_data && !m['data'].nil? then                
        if m['length'].nil?
          # length_pdu: number of octets (1 byte hex = 2 char) exclude smsc info        
          m['length'] = m['data'].index(/\r\n/im) || m['data'].size          
        end

        length = m['length'].to_i
        data = m['data'][0,length]      
        ext = m['data'][length..-1]
        m['data'] = data

        m[0] = ext # save non-processed data to key 0
      end    
      
      return m
    end

    # Match parameters with case. Return +true+ if match
    # [+m+] Hash of AT parameters
    def match_case(m)
      return false if @case_field.nil?
      return false if m[@case_field].nil?
      !m[@case_field].scan(@case_regexp).empty?
    end

    #---
    # Format Parsing 
    #+++

    private
	    def push_string(str)
	      @str << Regexp.escape(str) if !@has_data
	      last_block = @block.last
	      if !last_block.nil? && last_block[0] == :string then
	        last_block[1] << str
	      else
	        @block << [:string, str]
	      end
	    end
	    
	    def push_ascii(name)
	      if name == 'PROMPT' then
	        @block << [:prompt, true]
	      else
  	      str = SPECIAL_CHAR[name]
	        raise "at-cmd-fmt: push ascii nil = #{name}" if str.nil?    
	        push_string(str.clone)
	      end
	    end
	  
	    def push_name(name)
	      return if name.empty?    
	      return if @has_data
	      if name == 'data' then 
	        @has_data = true
	        @str << "(.*)"
	      else
	        @str << "(.+?)"
	      end    
	      @var[name.to_s] = @pos
	      @pos += 1
	      @block << [:name, name.to_s]
	    end  

	    def push_quoted(name)
	      return if name.empty?
	      return if @has_data 
	      @str << "(\"([^\"]*)\")?"
	      @var[name.to_s] = @pos + 1
	      @pos += 2
	      @block << [:quoted, name.to_s]
	    end
	  
	    def push_stack
	      return if @has_data
	      @str << "("
	      @pos += 1
	      new_block = []
	      @block << [:optional, new_block]
	      @stack_block.push @block
	      @block = new_block
	    end

	    def pop_stack
	      return if @has_data
	      raise 'at_cmd_fmt: pop_stack' if @stack_block.size <= 0
	      @str << ")?"
	      @block = @stack_block.pop
	    end

	    def compile_case(format)      
	      if !format.nil? then
	        @case_field,gx = format.scan(/(.*?)=(.*)/)[0]
	        @case_regexp = Regexp.new('^'+gx+'$', Regexp::IGNORECASE)
	      else
	        @case_field = nil
	        @case_regexp = nil
	      end
	    end

	    def compile(format)      
	      @var = {}
	      @root_block = []
	      @has_data = false
	      
	      @stack_block = []
	      @block = @root_block
	      @str = ''
	      @pos = 0

	      state = 'name'
	      name = ''
	      
	      format.each_byte { |b|
	        #data must be at tail
	        b = b.chr
	        case state
	          #--- name
	          when 'name'
	            case b
	              when '"'
	                push_name(name)
	                name = ''
	                state = 'quoted-name'
	              when '['
	                push_name(name)
	                push_stack
	                name = ''
	              when ']'
	                push_name(name)
	                pop_stack
	                name = ''
	              when '<'
	                push_name(name)
	                name = ''
	                state = 'ascii'            
	              when 'a'..'z','_'
	                name << b
	              else
	                push_name(name)
	                push_string(b)
	                name = ''
	            end #b

	          #--- quoted name
	          when 'quoted-name'
	            case b
	              when '"'
	                push_quoted(name)
	                name = ''
	                state = 'name'
	              when 'a'..'z','_'
	                name << b
	              else
	                raise 'at_cmd_fmt: compile quoted name else '
	            end # b

	          #--- ascii
	          when 'ascii'
	            case b
	              when '>'
	                push_ascii(name)
	                name = ''
	                state = 'name'
	              when '0'..'9','A'..'Z','-'
	                name << b  
	              else
	                raise 'at_cmd_fmt: compile ascii else '
	            end
	          
	        end # state
	      } if !format.nil?
	      push_name(name)
	      name = ''
	      raise 'at_cmd_fmt: compile stack' if @stack_block.size > 0

	      @str += '$'      
	      @regexp = Regexp.new(@str, Regexp::IGNORECASE | Regexp::MULTILINE)      
	    end

	    def build(var, block=@root_block)
	      str = ''
	      str_seqs = [] # sequence of str, splitted by prompt
	      
	      opt = 0
	      block.each { |bo|
	        case bo[0]
	          when :string 
	            str << bo[1]
	          when :prompt
	            str_seqs << str
	            str = ''
	          when :name, :quoted
	            val = var[bo[1]]
	            if !val.nil?
	              str << (bo[0] == :quoted ? "\"#{val}\"" : "#{val}")
	              opt += 1
	            end
	          when :optional
	            str_opt_seqs = build(var, bo[1])
	            if !str_opt_seqs.empty? then
	              str << str_opt_seqs.shift # concat with first
	              # merge if in opt has prompt (never ever wish to happen like this!) ---
	              str = str_tail if !(str_tail = str_opt_seqs.pop).nil?
	              str_seqs += str_opt_seqs
	              # end of the never happen --- 
	              opt += 1
	            end
	        end     
	      }
	      str_seqs << str if !str.empty?
	      # no option, just skip this
	      # skip if only in option bl0ck!!! (use equal?, not eql? or ==)
	      str_seqs = [] if opt == 0 && !block.equal?(@root_block)
	      str_seqs
	    end
	    
  end

  # This class hold many AtCommandFormats according to their case.
  # Sometimes, an AT command can have different format that is determine
  # by one or more of parameters' value.
  class AtCommandParser
    # Initialize new AtCommandParser.
    # [+name+] String ModemAtCommand's +name+
    # [+type+] String ModemAtCommand's +at_type+
    def initialize(name, type)
      @name = name
      @type = type
      @formats = {nil => AtCommandFormat.new(nil,nil)} #
    end
    
    # Add modem format and its case when should this format will be used
    # [+cse+] String of ModemAtCommand's +case_format+
    # [+fmt+] String of ModemAtCommand's +format+
    def add_case_and_format(cse,fmt)
      cse = nil if !cse.nil? && cse.strip.empty?
      @formats[cse] = AtCommandFormat.new(cse,fmt)
    end
    
    # Match AT code result parameters. Extended parameters (String
    # after line-feed) will be used if the AT code have data. This method
    # will select appropriate format according to case.
    # [+param+] String that is AT parameters
    # [+ext+] String after AT parameters (after line-feed)
    def match(param, ext)
      def_fmt = @formats[nil]
      return if def_fmt.nil?
      
      m = def_fmt.match(param, ext)

      # check better size 
      if @formats.size > 1 then
        @formats.each {|cse,fmt|
          next if fmt == def_fmt                    
          next if !fmt.match_case(m)
          
          m = fmt.match(param, ext)
          return m 
        }
        return
      else
        return m
      end
    end

    # Make AT code command. This method will use approriate format according
    # to case.
    # [+param+] Hash of AT parameters.
    def make(param = {})
      # raise 'at-cmd-parser: last command not final' if wait_final?
      # @cmd = @@cmd[id] || @@cmd[0]
      m = nil
      if @formats.size > 0 then
        def_fmt = @formats[nil]
        @formats.each {|cse,fmt|
          next if fmt == def_fmt
          next if !fmt.match_case(param)

          m = fmt.make(param)
          break
        }
        m = def_fmt.make(param) if m.nil? && !def_fmt.nil?
        return if m.nil?
      end
      
      if m.nil? || m.empty? then
        [ @name ]
      else
        m.clone.first.insert(0, @name + '=')
        m
      end
      # as: @name + ( m.nil? || m.empty? ? '' : '=' + m.to_s)
    end

  end

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
    attr_reader :responds
    attr_reader :got_prompt
    attr_reader :last_cmdfin # Get final response from last executed command.
    # Initialize ModemParser object.
    # [+modem_type+] ModemType model for specified modem's type
    def initialize(modem_type)
      @buffer = ''    # result buffer that not yet processed
      @cmd_name = nil # current command-name, and tell AT command that response is waited
      @cmd_atcommand = [] # current pending at command for @cmd_name, usually because prompt
      @got_prompt = false # cmd_prompt
      @responds = []  # unsoliciated results
      @parsers = {'UNSOLIC'=>{},'RESULT'=>{},'FINAL'=>{},'COMMAND'=>{}}
      @last_cmdfin = nil # last successfull command, avaiable after get final
      
      # standard command, ATA, ATH
      @parsers['COMMAND'].update( { 
        'H' => AtCommandParser.new('H','COMMAND'), #hang-up
        'A' => AtCommandParser.new('A','COMMAND')  #answer-call
      } )
      # standard unsolicited, RING
      @parsers['UNSOLIC'].update( {
        'RING' => AtCommandParser.new('RING','UNSOLIC') # ring-in
      } )
      
      # create AT command parser
      for at_cmd in modem_type.modem_at_commands do
        t = @parsers[at_cmd.at_type] || @parsers[at_cmd.at_type] = {}
        pars = t[at_cmd.name] || t[at_cmd.name] = AtCommandParser.new(at_cmd.name,at_cmd.at_type)
        pars.add_case_and_format(at_cmd.case_format,at_cmd.format)
      end
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
    def command(name, param = {})
      raise 'at-cmd-parser: last command not final' if wait_final?

      @cmd_name = name
      cmd  = @parsers['COMMAND'][@cmd_name]
      @got_prompt = 0
      
      if !cmd.nil? then
        # TODO: handle sperated (prompted) command
        @cmd_atcommand = cmd.make(param)
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
  
    # Retrive AT response by shifting out <tt>@responds</tt> array.
    def get_responds(&block) # :yields: respond
      if block.nil? then
        @responds.shift
      else 
        while !(responds = @responds.shift).nil? do block.call(responds) end      
      end
    end
 
    # Parse AT response then save it to <tt>@responds</tt> array.
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
      
      pre,rn,grp,c,ext,cprompt,ext2 = @buffer.scan(regexp_rn_result_rn)[0]         
      # pre must be empty!
      # ext or ext2
      @buffer = ext || ext2 || ''

      # get name
      if !c.nil? then
        name,sp,param = c.scan(/([^\:]+)(\:?\s?)(.*)/im)[0]      
        type = name.nil? ? 'STRING' : nil
        m = nil
      elsif !cprompt.nil? # get prompt
        type  = 'PROMPT'
        c = cprompt
        ext = ext2
      else
        return false
      end
      
      # check for unsolicited 1st, in case not prompt
      if @parsers['UNSOLIC'].has_key?(name) && m.nil? then
        pars = @parsers['UNSOLIC'][name]
        type = 'UNSOLIC' if !(m = pars.match(param, ext)).nil?
      end

      #check for command response, in case not unsolicited
      if !@cmd_name.nil? && m.nil? then
        if type.nil? then
          if @parsers['RESULT'].has_key?(name) && @cmd_name == name then
            pars = @parsers['RESULT'][name]
            type = 'RESULT' if !(m = pars.match(param, ext)).nil?
          elsif @parsers['FINAL'].has_key?(name) then
            pars = @parsers['FINAL'][name]
            type = 'FINAL' if !(m = pars.match(param, ext)).nil?
            @last_cmdfin = [@cmd_name, name, m]    
            @cmd_name = nil # end of AT command response
          # should this work? TODO: delete me if all GSM don flow to this
          # elsif c == "> " # may be prompt (that skipped by other unsolic dll) 
          #   type = 'PROMPT'
          end
        end
        if type == 'PROMPT'then
          @got_prompt += 1
          name, m = c, {} 
        end
        type, name, m = 'STRING', c, {} if m.nil?
      end
    
      # save mathcing params 
      if !m.nil? then
        ext = m.delete(0) if m.has_key?(0) #update ext, (after pars#match)
        @responds << [type, name, m]
      else
        @responds << [nil, c, nil]
      end

      @buffer = ext
      true
    end
  end
end
