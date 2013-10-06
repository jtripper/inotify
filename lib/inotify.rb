# lib/inotify.rb
# (C) 2013 jtRIPper
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 1, or (at your option)
# any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

require 'fiddle'

# Constants for each inotify event found in /usr/include/sys/inotify.h, descriptions from inotify man page (7), (note: When monitoring a directory, the events marked with an asterisk (*) above can occur for files in the directory, in which case the name field in the returned inotify_event structure identifies the name of the file within the directory.)
module InotifyEvents
  # File was accessed (read) (*).
  IN_ACCESS        = 0x00000001
  # File was modified (*).
  IN_MODIFY        = 0x00000002
  # Metadata  changed, e.g., permissions, timestamps, extended attributes, link count (since Linux 2.6.25), UID, GID, etc. (*).
  IN_ATTRIB        = 0x00000004
  # File opened for writing was closed (*). 
  IN_CLOSE_WRITE   = 0x00000008
  # File not opened for writing was closed (*).
  IN_CLOSE_NOWRITE = 0x00000010
  # File was closed (*).
  IN_CLOSE         = (IN_CLOSE_WRITE | IN_CLOSE_NOWRITE)
  # File was opened (*).
  IN_OPEN          = 0x00000020
  # Generated for the directory containing the old filename when a file is renamed (*).
  IN_MOVED_FROM    = 0x00000040
  # Generated for the directory containing the new filename when a file is renamed (*).
  IN_MOVED_TO      = 0x00000080
  # Generated when a file is moved (*).
  IN_MOVE          = (IN_MOVED_FROM | IN_MOVED_TO)
  # File/directory created in watched directory (*).
  IN_CREATE        = 0x00000100
  # File/directory deleted from watched directory (*).
  IN_DELETE        = 0x00000200
  # Watched file/directory was itself deleted.
  IN_DELETE_SELF   = 0x00000400
  # Watched file/directory was itself moved.
  IN_MOVE_SELF     = 0x00000800
  # Filesystem containing watched object was unmounted.
  IN_UNMOUNT       = 0x00002000
  # Event queue overfloved.
  IN_Q_OVERFLOW    = 0x00004000
  # Watch  was  removed  explicitly (inotify_rm_watch(2)) or automatically (file was deleted, or filesystem was unmounted).
  IN_IGNORED       = 0x00008000
  # Only watch pathname if it is a directory.
  IN_ONLYDIR       = 0x01000000
  # Don't dereference pathname if it is a symbolic link.
  IN_DONT_FOLLOW   = 0x02000000
  # By default, when watching events on the children of a directory, events are generated for children even after they have been unlinked from the directory.  This can result in large  numbers  of  uninteresting events for some applications (e.g., if watching /tmp, in which many applications create temporary files whose names are immediately unlinked).  Specifying IN_EXCL_UNLINK changes the default behavior, so that events are not generated for children after they have been unlinked from the watched directory.
  IN_EXCL_UNLINK   = 0x04000000
  # Add (OR) events to watch mask for this pathname if it already exists (instead of replacing mask).
  IN_MASK_ADD      = 0x20000000
  # Subject of this event is a directory.
  IN_ISDIR         = 0x40000000
  # Monitor pathname for one event, then remove from watch list.
  IN_ONESHOT       = 0x80000000
  # Set all events.
  IN_ALL_EVENTS    = (IN_ACCESS | IN_MODIFY | IN_ATTRIB | IN_CLOSE_WRITE \
                     | IN_CLOSE_NOWRITE | IN_OPEN | IN_MOVED_FROM \
                     | IN_MOVED_TO | IN_CREATE | IN_DELETE \
                     | IN_DELETE_SELF | IN_MOVE_SELF)
end

# The basic ctypes for every function required by inotify
module InotifyCtypes
  # open libc
  $libc = Fiddle.dlopen('/lib/libc.so.6')

  # import required functions
  $__inotify_init = Fiddle::Function.new(
    $libc['inotify_init'], 
    [], 
    Fiddle::TYPE_INT
  )

  $__inotify_add_watch = Fiddle::Function.new(
    $libc['inotify_add_watch'],
    [ Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT ],
    Fiddle::TYPE_INT
  )

  $__inotify_rm_watch = Fiddle::Function.new(
    $libc['inotify_rm_watch'], 
    [ Fiddle::TYPE_INT, Fiddle::TYPE_INT ], 
    Fiddle::TYPE_INT
  )

  $__read = Fiddle::Function.new(
    $libc['read'],
    [ Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT ],
    Fiddle::TYPE_INT
  )

  $__close = Fiddle::Function.new(
    $libc['close'],
    [ Fiddle::TYPE_INT ],
    Fiddle::TYPE_INT
  )

  # Parse the result of read on an inotify file descriptor.
  def inotify_event(buffer)
    wd, mask, cookie, len, name = buffer.unpack("lLLLZ*")
    event = Hash.new
    event["wd"]     = wd
    event["mask"]   = mask
    event["cookie"] = cookie
    event["len"]    = len
    event["name"]   = name
    event
  end

  # Open inotify file descriptor.
  def inotify_init
    $__inotify_init.call
  end

  # Add a path to the inotify watch.
  def inotify_add_watch(fd, path, mask)
    $__inotify_add_watch.call(fd, path, mask)
  end

  # Remove a watch descriptor from the inotify watch.
  def inotify_rm_watch(fd, wd)
    $__inotify_rm_watch.call(fd, wd)
  end

  # Allocate a buffer, call read and then parse the result.
  def inotify_read(fd)
    max_len = 20 + 1024 + 1
    cbuff = Fiddle::Pointer.malloc(max_len)
    max_len.times { |index| cbuff[index] = 0 }
    len = $__read.call(fd, cbuff, max_len)
    inotify_event(cbuff.to_s(len))
  end

  # Close inotify file descriptor.
  def inotify_close(fd)
    $__close.call(fd)
  end
end

# High-level class for using inotify in ruby.
#    puts "Watching #{ARGV[0]}"
#
#    inotify = Inotify.new
#    inotify.add_watch(ARGV[0], InotifyEvents::IN_CREATE|InotifyEvents::IN_MODIFY)
#
#    inotify.wait_for_event() { |path, mask, name|
#      puts "#{path}/#{name}"
#      if inotify.event?(mask, InotifyEvents::IN_CREATE)
#        puts " * created"
#      end
#      if inotify.event?(mask, InotifyEvents::IN_MODIFY)
#        puts " * modified"
#      end
#    }
#
#    inotify.rm_watch(ARGV[0])

class Inotify
  include InotifyCtypes
  include ObjectSpace

  def initialize
    @fd  = inotify_init
    @wds = {}

    define_finalizer(self, proc { close })
  end

  # Add a path to inotify watch (events found in InotifyEvents).
  def add_watch(path, event)
    @wds[inotify_add_watch(@fd, path, event)] = path
  end

  # Remove a path from inotify watch.
  def rm_watch(path)
    wd = @wds.key(path)
    if wd
      inotify_rm_watch(@fd, wd)
    end
  end

  # Close all watch descriptors.
  def rm_all_watches()
    @wds.values.each { |v| rm_watch(v) }
  end

  # Recursively add a path to inotify watch.
  def recursive_add_watch(path, event)
    add_watch(path, event)
    Dir.glob("#{path}/**/*/").each { |path|
      add_watch(path, event)
    }
  end

  # Wait for an inotify event to happen, yields the path, mask, and file name.
  def wait_for_event()
    event = inotify_read(@fd)
    yield @wds[event["wd"]],  event["mask"], event["name"]
  end

  # Check if an event is set in an event mask.
  def event?(mask, event_num)
    return (mask & event_num) != 0
  end

  # Close the inotify file descriptor.
  def close
    inotify_close(@fd)
  end
end

if __FILE__ == $0
  puts "Watching #{ARGV[0]}"

  inotify = Inotify.new
  inotify.add_watch(ARGV[0], InotifyEvents::IN_CREATE|InotifyEvents::IN_MODIFY)

  inotify.wait_for_event() { |path, mask, name|
    puts "#{path}/#{name}"
    if inotify.event?(mask, InotifyEvents::IN_CREATE)
      puts " * created"
    end
    if inotify.event?(mask, InotifyEvents::IN_MODIFY)
      puts " * modified"
    end
  }

  inotify.rm_watch(ARGV[0])
end
