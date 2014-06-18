= Rametook v0.3.4rc - 2008-05-14

== About

Send/Receive SMS via Modem/Serial Port using Ruby

== Features

* Can run as a daemon
* Communication using serial-port (/dev/tty)
* Multi-modems
* Text mode 
* AT command customizations with modem type profile
* CDMA/Text mode and GSM/PDU mode

== Installation

=== Requirements

1. Ruby extensions/gems:
   - rails 1.2.3
   - daemons 1.0.6
   - ruby-serial-port 0.6
2. OS: Linux 2.6.20-16, Win32 Windows XP (using Cygwin)
3. Database: MySQL 5.0.38 (supported by active-record)

NOTE:
Version is not minimal requirement, it just version that was being used
when start developing this application.

=== Steps

1. Install application databases using SQL 'rametook.sql'
2. Configure 'database.yml' for database connection.
3. Add/Edit record in table 'modem_devices' to register and enable 
   your modem as device.

== Usage

1. Connect and activate your modem to serial port (whatever tty)
2. Run application, type:

   ./rametook.rb run

   Press CTRL-C to stop program.
 
3. Run application as daemon, type:

   ./rametook.rb start
   
   To stop daemon, type:
   
   ./rametook.rb stop
   
== Development

Run 'doc.sh' script to create RDoc documentation for development.

Testing Phone:
- 02270499268 (CDMA-FLEXI)
- 081572292390 (GSM-MENTARI)
- 083829022820 (GSM-AXIS)
- 622270573111 (CDMA-FLEXI-111)

Still To Do:
* Pre-start, flushing buffer for made modem be prepared
* Full Unicode support, Test it!
* Automatic modem recognize
* Message Priority
* Multipart
* EMS/Ringtone/Logo messages

In Development:

Bugs:

== History

* 2008-05-14:
  - Fix, how to get working dir in Rametook and Rametook Control, also
    how to handle process that isn't belong to us (root)
  - Two versions of rametookctl, the new one using StatusIcon + PopupMenu,
    a nice start for controller example. And rametook icon :) from niwat0ri
  - Try creating a launcher on desktop/menus :P
  
* 2008-05-13:
  - Splitting Daemon
  - Still failing with T39m, becoz message-ref/ID (+CMGS: 0)
      
* 2008-05-09:
  - GSM/PDU mode implemented
  - Simple GUI controller

== Credits

Author::   firoDJ <firodj@yahoo.co.id>, <fadhil.mandaga@jerbeeindonesia.com>
Homepage:: http://firodj.info, http://www.friendster.com/firodj
License::  GNU General Public License (GPL) Version 3

