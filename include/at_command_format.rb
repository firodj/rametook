# This file is part of Rametook 0.4
module Rametook

class AtCommandFormat

    # Special characters (escaped characters) that is used in format string
    # for nice editing
    SPECIAL_CHAR = {'CR' => "\r", 'LF' => "\n", 'CTRL-Z' => "\C-z", 'ESC' => "\e"}

    # Initialize then compile format string and case
    # [+format+] String for format
    def initialize(format)
      make_regexp(format)
    end
    
    # Make AT command.
    # [+params+] Hash of parameters
    # If this command <tt>@has_data</tt>, this method will fill +length+ 
    # parameter with +data+ paramter size (String)
    def create(params = {})
      params['length'] = params['data'].size if @has_data && params['length'].nil?
      make_strings(params)
    end
    
    # Parsing AT command by parsing.
    # [+str+] String of AT response's parameters
    # [+ext+] String of extended parameters
    def parse(str, ext = '')  
      str_ext = @has_data ? str + ext : str

      s = str_ext.scan(@regexp)
      params = {}
      # get param 
      if !s[0].nil? then
        @params.each { |name,pos|
          params[name] = s[0][pos]
        }
      end
      # get data
      if @has_data && !params['data'].nil? then                
        if params['length'].nil?
          # length_pdu: number of octets (1 byte hex = 2 char) exclude smsc info        
          params['length'] = params['data'].index(/\r\n/im) || params['data'].size          
        end

        length = params['length'].to_i
        data = params['data'][0,length]      
        ext = params['data'][length..-1]
        params['data'] = data

        params[0] = ext # save non-processed data to key 0
      end    
      
      return params
    end
    
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
	        @str << "(.*?)" # before: (.+?)
	      end
	      @params[name.to_s] = @pos
	      @pos += 1
	      @block << [:name, name.to_s]
	    end  

	    def push_quoted(name)
	      return if name.empty?
	      return if @has_data
	      @str << "(\"([^\"]*)\")?"
	      @params[name.to_s] = @pos + 1
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
	    
      def make_regexp(format)      
	      @params = {}
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
	    
	    def make_strings(params, block=@root_block)
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
	            val = params[bo[1]]
	            if !val.nil?
	              str << (bo[0] == :quoted ? "\"#{val}\"" : "#{val}")
	              opt += 1
	            end
	          when :optional
	            str_opt_seqs = make_strings(params, bo[1])
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

end
