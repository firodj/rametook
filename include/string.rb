# This file is part of Rametook 0.4

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

  def to_sms_time
    # FIXME: see ActiveSupport
    t = self.scan(/([0-9]+)\/([0-9]+)\/([0-9]+),([0-9]+)\s\:([0-9]+)\s\:([0-9]+)/)
    begin
      Time.local(t[0][0], t[0][1], t[0][2], t[0][3], t[0][4], t[0][5])
    rescue ArgumentError
      nil
    end
  end
end

