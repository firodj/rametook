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

# for parsing HTML (gsm spec)
require 'cgi'
# for converting
require 'iconv'

class String

  # Swap each nibbles (a pair characters) in BCD string
  # (only for semi-decimal).
  #
  # Example: 1234567 (12 34 56 7F) to 214365F7 (21 43 65 F7)
  #
  # F character will be added to make even string before swapped
  # (also will be removed for reverse)
  #
  def nibble_swap
    len = self.length
    swap_str = ""
    str = self
    str += "F" if len % 2 != 0
  
    i = 0
    while i < len
      swap_str += str[i,2].reverse
      i += 2
    end
    swap_str.chomp! 'F'
    return swap_str
  end
end

# == PDU(protocol data unit) fundamentals
# This is the PDU class for write and read using SMS PDU format.
#
# === Glossary
# octets:: a group of 8 bits, often referred to as a byte. 
# septets:: a group of 7 bits
# kamprets:: a group of kampret <- ???
# decimal semi-octets:: 1 octet consists of 2 decimal digit that 
#                       nibble-swapped
#
# === Example
# septets (7-bit) to octets (8-bit):
#   string 'hello'    'h'     'e'     'l'     'l'     'o'
#   alphabet-dec      104     101     108     108     111     
#   bin7bit(msb>lsb)  1101000 1100101 1101100 1101100 1101111        
#   bin7bit(lsb->msb) 0001011 1010011 0011011 0011011 1111011
#   bin8bit(lsb->msb) 00010111 01001100 11011001 10111111 011.....
#   bin8bit(msb->lsb) 11101000 00110010 10011011 11111101 .....110
#   hex               E8       32       9B       FD       .6
#
class PDU
  # Binary to Hexadecimal
  Bin2Hex = {
    '0000' => '0', 
    '0001' => '1', 
    '0010' => '2',
    '0011' => '3', 
    '0100' => '4', 
    '0101' => '5', 
    '0110' => '6', 
    '0111' => '7', 
    '1000' => '8', 
    '1001' => '9', 
    '1010' => 'A', 
    '1011' => 'B', 
    '1100' => 'C',  
    '1101' => 'D', 
    '1110' => 'E', 
    '1111' => 'F'
    }
  
  # Hexadecimal to Binary
  Hex2Bin = Bin2Hex.invert
    
  # Binary to Character 7-bit (initialize later)
  Bin2Char = {}
  
  # Character 7-bit to Binary (initialize later)
  Char2Bin = {}

  # Type of address, Type of number
  ToaTon = ['unknown', 'intl', 'natl', 'net', 'sub', 'alpha', 'abbr', 'res']
  
  # Type of address, Numbering plan identifier
  ToaNpi = ['unknown', 'isdn/tel', nil, 'data', 'telex', 'scs', 'scs', nil,
            'nat', 'private', 'ermes', nil, nil, nil, nil, 'res' ]

  # First octet, flags
  FoDeliver = [nil,nil, '/tp-mms', nil,nil, 'tp-sri', 'tp-udhi', 'tp-rp']
  FoSubmit  = [nil,nil, 'tp-rd', nil,nil  , 'tp-srr', 'tp-udhi', 'tp-rp']
  FoStatusReport = [nil,nil, '/tp-mms', nil,nil, 'tp-srq', 'tp-udhi', nil]
  FoVpf = [nil, 'v-enh','v-rel', 'v-abs']
  FoMti = ['sms-deliver', 'sms-submit', 'sms-status-report']
  
  # DCS, coding
  DcsCoding = ['7-bit', '8-bit', 'ucs2', 'res']
  
  # Dcs, class
  DcsClass  = ['class-0','class-1','class-2','class-3']
    
  # Convert Ascii(utf-8) to octets Bin-7-bit
  def self.str2octet(str, fill_bits=0)
    octets = ''
    septets_count = 0
    b = '0' * fill_bits

    str_u = str.unpack('U*')
    l = str_u.size
    i = 0
    while i < l    
      bin = Char2Bin[ str_u[i] ]
      septets_count += bin.length / 7
      
      if !bin.nil? then
        bin.unpack('A7A7').each { |bb|
          b << bb.reverse if !bb.empty?
        }
        
        # into
        while b.length > 8 do
          b_rev = b[0..7].reverse
          octets << Bin2Hex[b_rev[0..3]] 
          octets << Bin2Hex[b_rev[4..7]]
          b = b[8..-1]
        end
        
      end
      i += 1
    end
    
    # end, residual
    if b.length > 0 then
      b << '0' * (8-b.length)
      b_rev = b.reverse
      octets << Bin2Hex[b_rev[0..3]]
      octets << Bin2Hex[b_rev[4..7]]
    end

    [octets, septets_count]
  end

  # Convert Hex Octets to Bin-7-bit
  def self.octets_to_bits7(octets, start=0)
    l = octets.length
    i = 0
    x = ''
    bits7 = []
    # convert from hexa to series of binary
    while i < l
      b = Hex2Bin[ octets[i].chr ] + Hex2Bin[ octets[i+1].chr ]
      x << b.reverse
      i += 2
    end
    # split each group of 7 bit then reverse it
    i = start* 7 # septet 7bit
    l = x.length
    while i < l
      b = x[i, 7].reverse # septet
      b_0 = 7 - b.length # bit-0 for padding
      b = ('0'*b_0)+b if b_0 > 0
      # DELETE THIS:
      # b = b[-b_0..-1] if b_0 < 0 # if not 7
      bits7 << b
      i += 7 # septet
    end
    bits7
  end
  
  # Convert Bin-7-bit to Ascii(utf-8)
  # +len+ is number of characters(septets) to be packed. Useful to avoid
  # "buy 7 will get 1" effect.
  def self.bits7_to_str(bits7, len=0)
    l = bits7.length
    l = len if 0 < len && len < l    
    str_u = []    
    
    i = 0    
    while i < l
      b = bits7[i]

      ch = Bin2Char[ b ]
      if ch == "\e"[0] && i + 1 < l then
        chesc = Bin2Char[ b + bits7[i+1] ]
        if !chesc.nil? then
          ch = chesc
          i += 1
        end
      end
      str_u << ch if !ch.nil?
      
      i += 1
    end

    str_u.pack('U*')    
  end
  
  # Convert Hex Octets to String as (UTF-8 or UTF-16-bigendian)
  def self.octets_to_str(octets, start=0)
    i = start* 2 # octet 2hex
    l = octets.length
    hh = ''
    while i < l
      hh += octets[i,2].hex.chr
      i += 2
    end
    hh
  end
  
  # Initilize PDU lookup-table and constant
  def self.init
    s = ''
    File.open('include/default_alphabet.html', 'r') { |f|
      s << f.read
    }

    s.scan(/<tr>.*$/i).each { |ss|        
      sss = ss.scan(/<td>(.*?)<\/td>/i)
      next if sss[0].nil? 
      hexa, deci, name, char, isod = sss

      isod = isod.first.split(' ').first
      hexa = hexa.first
      char = char.first
      deci = deci.first.split(' ')

      chara = if char.empty? then
        if isod.nil? then
          hexa.hex
        else
          isod.to_i
        end
      else
        c = CGI.unescapeHTML(char)
        if c.length > 1 then
          m = c.scan(/&#(.*);/)
          m[0][0].to_i if !m[0].nil?
        else
          c[0]
        end
      end
  
      bb = ''
      deci.each { |d|
        b = ''
        d = d.to_i
        while d > 0
          b = (d & 1).to_s + b
          d >>= 1
        end
        b = '0'*(7-b.length) + b if b.length < 7
        bb << b
      }
  
      Bin2Char[bb] = chara
      
      # puts "#{bb}, #{chara}, #{name} " + [chara].pack('U')
    }
    
    Char2Bin.update( Bin2Char.invert )
    
    # Freeze all constants
    Bin2Hex.freeze
    Hex2Bin.freeze
    Bin2Char.freeze
    Char2Bin.freeze
  end

  # initialize constants
  init
    
  # Write to PDU. This method will return PDU String.
  # +info+ is a Hash that contains:
  # [+smsc+] (optional) ms center
  # [+first_octet+] first octet (fo)
  # [+message_ref+] tp message reference (mr)
  # [+number+] mobile/phone number  
  # [+tp_pid+] (optional) tp pid
  # [+tp_valid+] (optional) tp validity
  # [+message+] user data
  #
  def self.write(info)
    pdu = ''
        
    if !info['smsc'].nil? && !info['smsc'].empty? then
      info['type_smsc'] = ['isdn/tel']
      info['type_smsc'] << 'intl' if info['smsc'][0,1] != '0'
      pdu_smsc = "%02X" % toa_ary2int(info['type_smsc'])      
      pdu_smsc << info['smsc'].nibble_swap      
      len_smsc = (pdu_smsc.length/2)
      pdu << "%02X" % len_smsc
      pdu << pdu_smsc
    else 
      pdu << '00'
    end
    pdu_length_skip = pdu.length
    
    tp_ud = '' 
    tp_udhl = 0
    
    if info['user_header'] && !info['user_header'].empty? then
      info['first_octet'] << 'tp-udhi'
      tp_udhl = info['user_header'].size / 2
      tp_udh = info['user_header'][0,tp_udhl*2].gsub(/[^0-9a-f]/i,'0') # validate
      tp_ud += "%02X" % tp_udhl
      tp_ud += tp_udh
    end
    
    pdu << "%02X" % fo_ary2int( info['first_octet'] )
    pdu << "%02X" % info['message_ref'] if info['first_octet'].include? 'sms-submit'
   
    info['type_number'] = []
    if info['number'].scan(/[^\d\*\#]+/).empty? then
      info['type_number'] << 'isdn/tel'
      info['type_number'] << 'intl' if info['number'][0,1] != '0'
      enc_number = info['number'].gsub('*', 'A' ).gsub('#', 'B').nibble_swap
      len_oa = info['number'].length
    else
      info['type_number'] << 'alpha'
      enc_number, enc_number_length = str2octet(info['number'])
      len_oa = (enc_number_length * 7 / 4.0).ceil # info['number'].length
    end
    
    pdu << "%02X" % len_oa
    pdu << "%02X" % toa_ary2int( info['type_number'] )    
    pdu << enc_number
    
    pdu << "%02X" % (info['tp_pid'] || 0)

    tp_udl = 0
    
    # TODO: cut data becoz limited by header
    info['data_coding'] ||= ['general', '7-bit']
    if info['data_coding'].include? '7-bit' # for default GSM (7-bit)
      tp_udsms = tp_udhl > 0 ? ((tp_udhl+1).to_f * 8 / 7).ceil : 0 # how much septets header?
      tp_udsm, tp_udsml = str2octet( info['message'], tp_udsms*7 % 8 )
      tp_ud += tp_udsm
      tp_udl = tp_udsms + tp_udsml
    elsif info['data_coding'].include? '8-bit' # 8-bit ANSI ISO
      tp_ud += info['message'].unpack('H*').to_s
      tp_udl = tp_ud.length / 2
    elsif info['data_coding'].include? 'ucs2' # 16-bit Big Endian
      tp_ud += begin
        Iconv.new('utf-16be', 'utf-8').iconv( info['message'] ).unpack('H*').to_s
      rescue # error on converting or unpacking
        ''
      end
      tp_udl = tp_ud.length / 2
    end
    
    pdu << "%02X" % dcs_ary2int( info['data_coding'] )

    if info['first_octet'].include? 'sms-deliver'      
      pdu << info['service_time'].strftime('%y%m%d%H%M%S00').nibble_swap
    elsif info['first_octet'].include? 'sms-submit'    	    
	    tp_vpf = info['first_octet'] & FoVpf
	    if !tp_vpf.empty?
	      if tp_vpf.include?('v-rel') then
  	      pdu << '%02X' % info['validity_period']
  	    else  	    
  	      pdu << info['validity_period'].strftime('%y%m%d%H%M%S00').nibble_swap
  	    end
	    end
	  end
    
    pdu << "%02X" % tp_udl
    pdu << tp_ud
    
    return [pdu, (pdu.length - pdu_length_skip) / 2]
  end
 
  # Read from PDU. +pdu+ is PDU String. 
  # the +actual_length+ is actual TP length (octets) in PDU,
  # it should be:
  # equal ( PDU ommitted the SCA - no smsc info), or
  # greater ( PDU starting with SCA)
  # This method will return Hash that contains:
  # [+type_smsc+] type of smsc number
  # [+smsc+] sms center number
  # [+first_octet+] first octet (fo)
  # [+type_number+] type of number
  # [+number+] mobile/phone number
  # [+data_coding+] data coding scheme
  # [+service_time+] service center time stamp
  # [+message+] message
  #
  def self.read(pdu, actual_length = nil)
    l = pdu.length
    i = 0    
    info = {}
    
    smsc_included = actual_length.nil? ? true : actual_length < l/2

    if smsc_included then
      len_smsc = pdu[0,2].hex
      j = (len_smsc+1)*2
      if len_smsc > 0 then
        toa_smsc = pdu[2,2].hex
        info['type_smsc'] = toa_int2ary(toa_smsc)
          
        # smsc must be not alpha, otherwise for now error
        # TODO: smsc alpha
        raise 'pdu_read: smsc is alpha?' if info['type_smsc'].include?('alpha')
          
        enc_smsc = pdu[4..j-1] 
        info['smsc'] = enc_smsc.nibble_swap      
      end  
      
      pdu = pdu[j..-1]
    end

    # FIRST OCTET: all
    fo = pdu[0,2].hex
    info['first_octet'] = fo_int2ary(fo)
    
    # TP-MR: sms-submit, sms-status-report
    if !(info['first_octet'] & ['sms-submit','sms-status-report']).empty? then
      info['message_ref'] = pdu[2,2].hex
      pdu = pdu[2..-1]
    end
    
    # TP-OA: sms-deliver
    # TP-DA: sms-submit
    # TP-RA: sms-status-report
    len_oa = pdu[2,2].hex # number of used nibble
    j = 6 + len_oa + (len_oa % 2)

    toa_number = pdu[4,2].hex
    info['type_number'] = toa_int2ary(toa_number)
        
    enc_number = pdu[6..j-1]    
    x_alpha = info['type_number'].include?('alpha')
    info['number'] = x_alpha ? 
      PDU.bits7_to_str( PDU.octets_to_bits7(enc_number), len_oa*4/7) : 
      enc_number.nibble_swap.gsub('A','*').gsub('B','#')
    
    pdu = pdu[j..-1]
    
    if info['first_octet'].include?('sms-status-report')
      # TP-SCTS: sms-status-report
      tp_scts = pdu[0,14].nibble_swap
	    # "GMT: #{tp_scts[12,2]}"
	    info['service_time'] = begin
	      Time.local(tp_scts[0,2],
	        tp_scts[2,2],
	        tp_scts[4,2],
	        tp_scts[6,2],
	        tp_scts[8,2],
	        tp_scts[10,2] )
	    rescue ArgumentError
	      nil
	    end
	    
	    tp_dt = pdu[14,14].nibble_swap
	    # "GMT: #{tp_scts[12,2]}"
	    info['discharge_time'] = begin
	      Time.local(tp_dt[0,2],
	        tp_dt[2,2],
	        tp_dt[4,2],
	        tp_dt[6,2],
	        tp_dt[8,2],
	        tp_dt[10,2] )
	    rescue ArgumentError
	      nil
	    end
	    
	    tp_st = pdu[28,2].hex
	    info['status_report'] = tp_st
	    
	    tp_pi = pdu[30,2].hex
	    info['tp_pi'] = tp_pi
	    # pid,dcs,udl
	    	    
	    pdu = pdu[32..-1]
	    
	    # skip others, usually tp_pi is 00, so no follow fields
	    return info
    end
         
    # TP-PID: all
    tp_pid = pdu[0,2].hex
    info['tp_pid'] = tp_pid

    # TP-DCS: all
    tp_dcs  = pdu[2,2].hex
    info['data_coding'] = dcs_int2ary(tp_dcs)

    jh = 4
    if info['first_octet'].include?('sms-deliver')
	    # TP-SCTS: sms-deliver
	    
	    tp_scts = pdu[jh,14].nibble_swap
	    jh += 14
	    
	    # "GMT: #{tp_scts[12,2]}"
	    
	    info['service_time'] = begin
	      Time.local(tp_scts[0,2],
	        tp_scts[2,2],
	        tp_scts[4,2],
	        tp_scts[6,2],
	        tp_scts[8,2],
	        tp_scts[10,2] )
	    rescue ArgumentError
#p tp_scts
	      nil
	    end
	  elsif info['first_octet'].include?('sms-submit')
	    # TP-VP: sms-submit
	    tp_vpf = info['first_octet'] & FoVpf
	    if !tp_vpf.empty?
	      if tp_vpf.include?('v-rel') then
	        info['validity_period'] = pdu[jh,2].hex
	        jh += 2
	      else
	        tp_vp = pdu[jh,14].nibble_swap
	        jh += 14
	        
     	    info['validity_period'] = begin
			      Time.local(tp_vp[0,2],
			        tp_vp[2,2],
			        tp_vp[4,2],
			        tp_vp[6,2],
			        tp_vp[8,2],
			        tp_vp[10,2] )
			    rescue ArgumentError
			      nil
			    end
	      end
	    end
	  end
    
    # TP-UDL & TP-UD: sms-deliver
      
    # octets, or septets (number characters in message)
    # for ucs2 (16-bit) count as octets not as hextets (1 hextet = 2 octets)
    tp_udl = pdu[jh,2].hex     
    ##info['tp_udl'] = tp_udl
    tp_ud  = pdu[(jh+2)..-1] # pdu
    tp_udsml, tp_udsms = tp_udl, 0 # sm-length, and sm-start

    if info['first_octet'].include? 'tp-udhi' then
      tp_udhl = tp_ud[0,2].hex
      info['user_header'] = tp_ud[2, tp_udhl*2]
      tp_udsms = ((tp_udhl+1).to_f * 8 / (info['data_coding'].include?('7-bit') ? 7 : 8)).ceil
      tp_udsml -= tp_udsms
    end
    
    # gsm 3.38 octets to utf-8
    info['message'] = if info['data_coding'].include? '7-bit' then
      PDU.bits7_to_str( PDU.octets_to_bits7(tp_ud, tp_udsms), tp_udsml )
    elsif info['data_coding'].include? '8-bit'
      octets_to_str( tp_ud, tp_udsms )
    elsif info['data_coding'].include? 'ucs2'
      ud_as_utf16be = octets_to_str( tp_ud, tp_udsms )
      begin
        Iconv.new('utf-8', 'utf-16be').iconv(ud_as_utf16be)
      rescue # error in converting
        nil
      end
    else # unknown/reserved data coding
      nil
    end

    return info
  end

  # Type-of-address to array
  # bit 7:: always 1  3..1 
  # bit 6 5 4::   Type-of-number   
  # bit 3 2 1 0:: Numbering-Plan-Identification
  def self.toa_int2ary(toa_int)
    return [] if toa_int.nil?
    toa_ary = []
    toa_npi = ToaNpi[toa_int & 0xF]
    toa_ton = ToaTon[(toa_int & 0x70) >> 4]
    toa_ary << toa_npi if !toa_npi.nil?
    toa_ary << toa_ton if !toa_ton.nil?
    toa_ary << 'notset' if (toa_int & 0x80 == 0)
    toa_ary
  end
  
  def self.toa_ary2int(toa_ary)
    toa_int = 0x0
    if !toa_ary.include? 'notset' then
      toa_int |= 0x80
	    toa_npi = (toa_ary & ToaNpi).first
	    toa_int |= ToaNpi.index(toa_npi) if !toa_npi.nil?    
	    toa_ton = (toa_ary & ToaTon).first
	    toa_int |= ToaTon.index(toa_ton) << 4 if !toa_ton.nil?
    end    
    toa_int
  end
  
  # First-octet to array
  # bit 7:: TP-RP (reply path exists)
  # bit 6:: TP-UDHI (User data header indicator)
  # bit 5:: TP-SRI (Status report indication) [DELIVER]
  #         TP-SRR (Status report request) [SUBMIT]
  # bit 4 3:: TP-VPF (Validity period format) [SUBMIT]
  # bit 2:: TP-MMS (More messages to send) inverted [DELIVER]
  #         TP-RD (Reject duplicates) [SUBMIT]  
  # bit 1 0:: TP-MTI (Message type indicator)
  def self.fo_int2ary(fo_int)
    return [] if fo_int.nil?
    fo_ary = []
    tp_mti = FoMti[fo_int & 0x3]    
    fo_ary << tp_mti if !tp_mti.nil?
    
    i = 0x1
    fo_flag = {'sms-deliver' => FoDeliver,
      'sms-submit' => FoSubmit,
      'sms-status-report' => FoStatusReport
    }[tp_mti]

    fo_flag.each { |f|
      if !f.nil? then
        b = (fo_int & i) != 0
        if f[0,1] == '/' then
          b = !b
          f = f[1..-1]
        end      
        fo_ary << f if b
      end
      i <<= 1      
    }
    if tp_mti == 'sms-submit' then
      tp_vpf = FoVpf[(fo_int >> 3) & 0x3]
      fo_ary << tp_vpf if !tp_vpf.nil?
    end
    fo_ary
  end
  
  def self.fo_ary2int(fo_ary)
    fo_int = 0x0
    tp_mti = (fo_ary & FoMti).first
    fo_int |= FoMti.index(tp_mti) if !tp_mti.nil?
    
    i = 0x1
    fo_flag = {'sms-deliver' => FoDeliver,
      'sms-submit' => FoSubmit,
      'sms-status-report' => FoStatusReport
    }[tp_mti]
    
    fo_flag.each { |f|
      if !f.nil? then
        b_1 = false
        if f[0,1] == '/'
          f = f[1..-1] 
          b_1 = true
        end
        b = fo_ary.include? f
        b = !b if b_1
        fo_int |= i if b
      end
      i <<= 1      
    }
    if tp_mti == 'sms-submit' then
      tp_vpf = (fo_ary & FoVpf).first
      fo_int |= FoVpf.index(tp_vpf) << 3 if !tp_vpf.nil?
    end
    
    fo_int
  end
  
  # Data coding scheme
  def self.dcs_int2ary(dcs_int)
    return [] if dcs_int.nil?
    dcs_ary = []
    if (dcs_int & 0xC0 == 0) || (dcs_int & 0xF0 == 0xF0) then
      # (general) message class/data coding
      hv_class = true
      if (dcs_int & 0xC0 == 0) then
        dcs_ary << 'general'
        dcs_ary << 'compress' if dcs_int & 0x20 != 0        
        hv_class = dcs_int & 0x10 != 0       
      end
      dcs_ary << DcsClass[dcs_int & 0x3] if hv_class
      dcs_ary << DcsCoding[(dcs_int >> 2) & 0x3]
    elsif (dcs_int & 0xC0 == 0xC0) then
      # coding/indication group
      # not yet implemented
      dcs_ary << 'group'
    end
    dcs_ary
  end
  
  def self.dcs_ary2int(dcs_ary)
    dcs_int = 0x0
    if dcs_ary.include? 'group' then
      dcs_int |= 0xC0
    else
      if dcs_ary.include? 'general' then
        dcs_int |= 0x20 if dcs_ary.include? 'compress'        
      else
        dcs_int |= 0xF0
      end
      dcs_coding = (dcs_ary & DcsCoding).first      
      dcs_int |= DcsCoding.index(dcs_coding) << 2 if !dcs_coding.nil?      
      dcs_class = (dcs_ary & DcsClass).first
      if !dcs_class.nil? then
        dcs_int |= 0x10
        dcs_int |= DcsClass.index(dcs_class)
      end
    end
    dcs_int
  end
end

