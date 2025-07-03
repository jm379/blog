require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'ffi'
end

module Inotify
  extend FFI::Library

  ffi_lib 'lib/libinotify.so'

  attach_function :init, [], :int32
  attach_function :add_watch, [:int32, :string, :uint32], :int32
  attach_function :rm_watch, [:int32, :uint32], :void

  callback :callback, [:int32, :uint32, :uint32, :uint32, :string], :void
  attach_function :watch, [:int32, :callback], :void, blocking: true
end

module Inotify
  module Flags
    IN_ACCESS=0x00000001
    IN_MODIFY=0x00000002
    IN_ATTRIB=0x00000004
    IN_CLOSE_WRITE=0x00000008
    IN_CLOSE_NOWRITE=0x00000010
    IN_CLOSE=(IN_CLOSE_WRITE | IN_CLOSE_NOWRITE)
    IN_OPEN=0x00000020
    IN_MOVED_FROM=0x00000040
    IN_MOVED_TO=0x00000080
    IN_MOVE= (IN_MOVED_FROM | IN_MOVED_TO)
    IN_CREATE=0x00000100
    IN_DELETE=0x00000200
    IN_DELETE_SELF=0x00000400
    IN_MOVE_SELF=0x00000800
    # Events sent by the kernel.
    IN_UNMOUNT=0x00002000
    IN_Q_OVERFLOW=0x00004000
    IN_IGNORED=0x00008000
    IN_ONLYDIR=0x01000000
    IN_DONT_FOLLOW=0x02000000
    IN_MASK_ADD=0x20000000
    IN_ISDIR=0x40000000
    IN_ONESHOT=0x80000000
    IN_ALL_EVENTS=(IN_ACCESS | IN_MODIFY | IN_ATTRIB | IN_CLOSE_WRITE \
                            | IN_CLOSE_NOWRITE | IN_OPEN | IN_MOVED_FROM \
                            | IN_MOVED_TO | IN_CREATE | IN_DELETE \
                            | IN_DELETE_SELF | IN_MOVE_SELF)
  end
end

pid = fork do
  Signal.trap('INT') do
    exit
  end

  fd = Inotify.init
  wd = Inotify.add_watch(fd, '../backup', Inotify::Flags::IN_ALL_EVENTS)
  Inotify.watch(fd) do |wd, mask, cookie, len, name|
    puts "wd: #{wd}, mask: #{mask}, cookie: #{cookie}, len: #{len}, name: #{name}"
  end
  exit
end

puts 'Press ctrl-C to exit'
Signal.trap('INT') do
  puts ''
  puts 'Exiting...'
  Process.kill 'KILL', pid
  exit
end

Process.waitall
