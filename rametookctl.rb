#!/usr/bin/env ruby
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

GUI_VERSION = "0.1.1"

require 'rubygems'
require 'gtk2'
require 'libglade2'

# check if process with given pid is running
def running_pid?(pid)
  return false if pid.nil?
  begin
    Process.kill(0, pid)
    return true
  rescue Errno::ESRCH
    return false
  rescue Errno::EPERM   
    # for example on EPERM (process exists but does not belong to us), ex. as root
    return true
  rescue # ::Exception
  end
  return false
end

# Rametook Controller
# using GUI bindings with Ruby/GNOME2
class RametookControl
  def initialize
    file_path = File.expand_path(__FILE__)
    @dir = File.dirname( file_path ) # working_directory    
    Dir.chdir @dir # change dir, its not necessary may be!
        
    @rametook_dir = @dir
    @rametook_name = 'rametook.rb'    
    p @rametook_dir
    
    @glade = GladeXML.new("rametookctl.glade") {|handler| method(handler)}    
    @main_window = @glade['main_window']    
    @main_window.signal_connect('delete-event') {|widget,event|
      @main_window.hide
      true
    }
    
    @info_label  = @glade['info_label']
    @log_textview = @glade['log_textview']
    @log_textview_scroll = @glade['log_textview_scroll']
    @notification_menu = @glade['notification_menu']
    
    @status_icon = Gtk::StatusIcon.new         
    @status_icon.stock = 'gtk-no' #Gtk::Stock::YES
    @status_icon.visible = true

    @status_icon.signal_connect('popup_menu') { |widget,button,activate_time| 
      @notification_menu.popup(nil, nil, button, activate_time) { |menu, x, y, pushin|
         @status_icon.position_menu(@notification_menu)
      }
    }
    @status_icon.signal_connect('activate') { on_show_hide_window }
    
    show_rametook_version
    show_rametook_status
    
    # read the status next 1secs
    GLib::Timeout.add_seconds(10) { on_timeout_check_running }
    
    Gtk.main
  end
  
  # event handlers
  # --------------
  
  def on_testing_clicked
    
  end
  
  def on_main_window_destroy    
    #puts "main window destroy"
    Gtk.main_quit    
  end
   
  def on_show_hide_window
    @main_window.visible = !@main_window.visible?
  end
  
  def on_timeout_check_running    
    show_rametook_status
    true
  end
  
  def show_rametook_version
    run_command "ruby #{@rametook_dir}/rametook.rb --version", "Rametook Version:"
  end
 
  def on_start_stop_clicked
    if rametook_running? then
      run_command "ruby #{@rametook_dir}/rametook.rb stop", "Rametook Stop!"
    else
      run_command "ruby #{@rametook_dir}/rametook.rb start", "Rametook Start!"
    end
    sleep(1)
    show_rametook_status
  end
     
  def show_rametook_status
    @status_icon.stock = rametook_running? ? 'gtk-yes' : 'gtk-no'
    @status_icon.tooltip = rametook_running? ? 'Rametook run' : 'Rametook stop'
    @info_label.label = rametook_running? ? 'Run' : 'Stop'
  end  
    
  # other functions
  # ---------------
  
  # same as MFC.PumpMessages
  def pump_events
    while (Gtk.events_pending?)
      Gtk.main_iteration
    end
  end
  
  def rametook_running?  
    pid_files = Dir[File.join(@rametook_dir, "#{@rametook_name}.pid")]    
    pid_files.delete_if { |f| if (File.file?(f) and File.readable?(f)) then
        pid = File.open(f) {|h| h.read}.to_i rescue nil
        !running_pid?(pid)
      else
        true
      end
    }
    not pid_files.empty?    
  end

  def run_command(cmd, title = nil)
    @log_textview.buffer.insert(@log_textview.buffer.end_iter, "========== #{title} ==========\n") if title
    IO.popen(cmd) { |f|
      while (s = f.gets) do
        @log_textview.buffer.insert(@log_textview.buffer.end_iter, s)        
      end      
    }
    pump_events
    @log_textview.buffer.insert(@log_textview.buffer.end_iter, "\n")    
    
    # scroll the the latest        
    @log_textview_scroll.vadjustment.clamp_page( 
      @log_textview_scroll.vadjustment.upper - @log_textview_scroll.vadjustment.page_size,
      @log_textview_scroll.vadjustment.upper )
  end

end

RametookControl.new

