require 'inotify'

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

