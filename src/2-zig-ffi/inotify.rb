#!/usr/bin/env ruby

# Require the Inotify interface defined in the ext/inotify/inotify file
require_relative 'ext/inotify/inotify'

# Get the file path from command-line arguments
path = ARGV.pop
unless path
  puts 'Error: A file path must be provided.'
  exit 1
end

# Defining a method to close the file descriptors
def cleanup
  puts 'Cleaning descriptors'
  Inotify.rm_watch @wd, @fd
  IO.new(@fd).close
end

# Set up a signal trap for the INT signal (Ctrl+C) to handle graceful termination
Signal.trap('INT') do
  puts ''
  puts 'Exiting'
  cleanup
  exit
end

puts "Watching for Inotify events in `#{path}'"
puts 'Press ctrl-C to exit'

# Initialize Inotify and create a non-blocking file descriptor
@fd = Inotify.init Inotify::IN_NONBLOCK
# Add a watch on the specified path for all Inotify events
@wd = Inotify.add_watch(@fd, path, Inotify::Flags::IN_ALL_EVENTS)

# Creating a lambda to process the Inotify event
callback = lambda do |event, name|
  puts "wd: #{event[:wd]}, mask: #{event[:mask].to_s(16)}, flags: #{event.flags}, cookie: #{event[:cookie]}, len: #{event[:len]}, name: #{name}"
end

# Start an infinite loop to continuously check for Inotify events
loop do
  rval = Inotify.watch(@fd, &callback)

  # Checking if failed to read the Inotify file descriptor
  unless [-1, 0].include?(rval)
    puts "Failed to read Inotify descriptor: #{rval}"
    cleanup
    exit 1
  end
end
