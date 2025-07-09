#!/usr/bin/env ruby

require_relative 'ext/inotify/inotify'

path = ARGV.pop
unless path
  puts 'Error: A file path must be provided.'
  exit 1
end

Signal.trap('INT') do
  puts ''
  puts 'Exiting...'
  Inotify.rm_watch(@wd, @fd)
  IO.new(@fd).close
  exit
end

puts "Watching for Inotify events in `#{path}'"
puts 'Press ctrl-C to exit'

@fd = Inotify.init(Inotify::Flags::IN_NONBLOCK)
@wd = Inotify.add_watch(@fd, path, Inotify::Flags::IN_ALL_EVENTS)

loop do
  Inotify.watch(@fd) do |event, name|
    puts "wd: #{event[:wd]}, mask: #{event[:mask].to_s(16)}, cookie: #{event[:cookie]}, len: #{event[:len]}, name: #{name}"
  end
end
