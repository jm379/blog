require_relative 'ext/inotify/inotify'

Signal.trap('INT') do
  puts ''
  puts 'Exiting...'
  Inotify.rm_watch(@wd, @fd)
  exit
end
puts 'Press ctrl-C to exit'

@fd = Inotify.init(Inotify::Flags::IN_NONBLOCK)
@wd = Inotify.add_watch(@fd, './', Inotify::Flags::IN_ALL_EVENTS)

loop do
  Inotify.watch(@fd) do |event, name|
    puts "wd: #{event[:wd]}, mask: #{event[:mask].to_s(16)}, cookie: #{event[:cookie]}, len: #{event[:len]}, name: #{name}"
  end
end
