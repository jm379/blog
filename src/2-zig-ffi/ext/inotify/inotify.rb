# Use inline Bundler to manage dependencies, specifically the
# 'ffi' gem for foreign function interface
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'ffi'
end

module Inotify
  extend FFI::Library
  IN_NONBLOCK = 0000_4000 # Non-blocking flag

  # Define a class to represent an Inotify event struct
  class Event < FFI::Struct
    layout :wd,     :int32,
           :mask,   :uint32,
           :cookie, :uint32,
           :len,    :uint32

    # Method to get the flags from the mask field 
    def flags
      Flags.flags self[:mask]
    end
  end

  # Load the C standard library and the shared Inotify library created by Zig
  ffi_lib FFI::Library::LIBC,
          File.join(File.dirname(__FILE__), 'lib', 'libinotify.so')

  # Attach functions from the Inotify shared library
  attach_function :init, :inotify_init1, [:int], :int
  attach_function :add_watch, :inotify_add_watch, [:int, :string, :uint32], :int
  attach_function :rm_watch, :inotify_rm_watch, [:int, :uint32], :int

  # Define a callback type for handling Inotify events
  callback :callback, [Event.by_ref, :string], :void
  attach_function :watch, [:int32, :callback], :int32

  # Define flags for various Inotify events,
  # based on the Linux kernel definitions
  module Flags
    IN_ACCESS         = 0x0000_0001 # File was accessed
    IN_MODIFY         = 0x0000_0002 # File was modified
    IN_ATTRIB         = 0x0000_0004 # Metadata changed
    IN_CLOSE_WRITE    = 0x0000_0008 # Writable file was closed
    IN_CLOSE_NOWRITE  = 0x0000_0010 # Unwritable file closed
    IN_OPEN           = 0x0000_0020 # File was opened
    IN_MOVED_FROM     = 0x0000_0040 # File was moved from X
    IN_MOVED_TO       = 0x0000_0080 # File was moved to Y
    IN_CREATE         = 0x0000_0100 # Subfile was created
    IN_DELETE         = 0x0000_0200 # Subfile was deleted
    IN_DELETE_SELF    = 0x0000_0400 # Self was deleted
    IN_MOVE_SELF      = 0x0000_0800 # Self was moved

    # the following are legal events.  they are sent as needed to any watch
    IN_UNMOUNT    = 0x0000_2000 # Backing fs was unmounted
    IN_Q_OVERFLOW = 0x0000_4000 # Event queued overflowed
    IN_IGNORED    = 0x0000_8000 # File was ignored

    # helper events
    IN_CLOSE  = (IN_CLOSE_WRITE | IN_CLOSE_NOWRITE) # close
    IN_MOVE   = (IN_MOVED_FROM | IN_MOVED_TO) # moves

    # special flags
    IN_ONLYDIR      = 0x0100_0000 # only watch the path if it is a directory
    IN_DONT_FOLLOW  = 0x0200_0000 # don't follow a sym link
    IN_EXCL_UNLINK  = 0x0400_0000 # exclude events on unlinked objects
    IN_MASK_CREATE  = 0x1000_0000 # only create watches
    IN_MASK_ADD     = 0x2000_0000 # add to the mask of an already existing watch
    IN_ISDIR        = 0x4000_0000 # event occurred against dir
    IN_ONESHOT      = 0x8000_0000 # only send event once

    # All of the events - we build the list by hand so that we can add flags in
    # the future and not break backward compatibility.  Apps will get only the
    # events that they originally wanted.  Be sure to add new events here!
    IN_ALL_EVENTS = (IN_ACCESS | IN_MODIFY | IN_ATTRIB | IN_CLOSE_WRITE |
                     IN_CLOSE_NOWRITE | IN_OPEN | IN_MOVED_FROM |
                     IN_MOVED_TO | IN_DELETE | IN_CREATE | IN_DELETE_SELF |
                     IN_MOVE_SELF)

    # Method to get all the flags encoded from a mask value
    def self.flags(mask)
      constants.filter do |const_name|
        const_value = const_get(const_name)
        (const_value & mask) == const_value
      end
    end
  end
end
