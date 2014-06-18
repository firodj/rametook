open("/dev/tty", "r+") { |tty|
  while true do
    c = tty.getc
    print 'fad'
    print c
  end
}
