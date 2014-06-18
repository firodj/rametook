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

  # This class connecting to database using <tt>ActiveRecord</tt>
  class Database
    @conn_spec = {}
    
    # Load database configuration from YAML <tt>file_name</tt>    
    def self.load_config(file_name)
      @conn_spec = File.open(file_name) { |yf|
        YAML.load( yf ) 
      }
    end
    
    # Save database configuration to YAML <tt>file_name</tt>
    def self.save_config(file_name)
      File.open(file_name, 'w') { |yf|
        YAML.dump( @conn_spec, yf )
      }
    end
    
    # Set database configuration
    def self.conn_spec=(conn_spec)
      @conn_spec = conn_spec
    end
    
    # Establish connection using database configuration
    def self.establish
      Utility.log_msg "Connecting to database: #{@conn_spec['database']}@#{@conn_spec['host']}"
      ActiveRecord::Base.establish_connection(@conn_spec)      
    end
  end

  class ModemType < ActiveRecord::Base #:nodoc: all
    has_many :modem_at_commands
    has_many :modem_at_functions
    has_many :modem_devices
  end

  class ModemAtCommand < ActiveRecord::Base #:nodoc: all
    belongs_to :modem_type
  end

  class ModemAtFunction < ActiveRecord::Base #:nodoc: all
    belongs_to :modem_type
  end

  class ModemDevice < ActiveRecord::Base #:nodoc: all
    belongs_to :modem_type
  end

  class ModemShortMessage < ActiveRecord::Base
    belongs_to :modem_device
    has_many :modem_pdu_logs
    
    # status value (may be not saved on db, but used on the fly)
    # INBOX
    # OUTBOX
    # PROCESS
    # SENDING
    # WAITING
    # UNSENT
    # RESEND
    # SENT
    # FAIL
    
    # Convert attributes to hash
    def to_hash
      hash = {}
      for column_name in ModemShortMessage.column_names
        hash[column_name] = self.send(column_name)
      end
      hash
    end
    
    # Set attributes from hash
    def from_hash( hash)
      for column_name in ModemShortMessage.column_names
        self.send(column_name + '=', hash[column_name]) if !hash[column_name].nil?
      end
    end
  end
  
  class ModemPduLog < ActiveRecord::Base
    belongs_to :modem_short_message
  end
end
