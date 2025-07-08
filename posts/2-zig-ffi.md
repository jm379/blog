---
title: Zig FFI
date: 2025-07-01
---

## Introduction

In this post, we are going to explore how to extend Ruby using [Zig](https://ziglang.org/), by creating
a shared library and utilizing it with the [FFI gem](https://github.com/ffi/ffi). This approach can
yield similar results with other languages like [Rust](https://www.rust-lang.org/) and [Golang](https://go.dev/).

### What's a shared library?

A shared library is a collection of code and data that can be used by multiple programs simultaneously.
Unlike static libraries, which are linked into an application at compile time, shared libraries are
loaded into memory at runtime. This allows for more efficient use of system resources, as multiple
applications can share the same library code, reducing redundancy.

Shared libraries typically have a file extension such as `.so` (for Linux), `.dll` (for Windows). 
They provide a way to modularize code, making it easier to update and maintain. When a shared library
is updated, all applications that use it can benefit from the improvements without needing to be
recompiled.

### But... Why Zig?

Zig is a young yet capable systems language that introduces many features focused on safety,
error handling, and explicit memory management, along with excellent interoperability with C
and an impressive build system. This makes it a powerful tool in a very different—and potentially
more dangerous—world compared to Ruby.

## Inotify

[Inotify](https://www.man7.org/linux/man-pages/man7/inotify.7.html) is a Linux kernel feature that
was merged in the version 2.6.13, allowing programs to monitor file system events, such as modifications,
deletions, and creations of files and directories without the need for constant polling. This makes
Inotify efficient and ideal for applications that require immediate updates based on file changes,
such as file synchronization, real-time monitoring tools and hot reloading of code.

### Codify

TODO:
- Brief introduction on what are we going to write

```bash
mkdir -p ext/inotify && \
touch inotify.rb ext/inotify/inotify.rb ext/inotify/inotify.zig ext/inotify/build.zig && \
tree
.
├── ext
│   └── inotify
│       ├── build.zig
│       ├── inotify.rb
│       └── inotify.zig
└── inotify.rb

3 directories, 4 files
```


```zig
// ext/inotify/inotify.zig

const std = @import("std");
const posix = std.posix;
const InotifyEvent = std.os.linux.inotify_event;
const inotify = @cImport(@cInclude("sys/inotify.h"));

const Callback = *const fn (event: *InotifyEvent, name: [*:0]const u8) callconv(.C) void;

export fn watch(fd: i32, cb: Callback) callconv(.C) i32 {
    var buff: [@sizeOf(InotifyEvent) + posix.PATH_MAX:0]u8 align(@alignOf(InotifyEvent)) = undefined;
    var read: usize = undefined;
    var idx: usize = 0;
    var event: *InotifyEvent = undefined;

    read = posix.read(fd, &buff) catch |err| {
        return switch (err) {
            error.WouldBlock => -1,
            else => -2,
        };
    };

    while (idx < read) {
        event = @ptrCast(@alignCast(buff[idx..read]));
        idx += @sizeOf(InotifyEvent) + event.len;
        const name = event.getName() orelse "";
        cb(event, name);
    }
    return 0;
}
```

```zig
// ext/inotify/build.zig

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const lib = b.addSharedLibrary(.{
        .name = "inotify",
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("inotify.zig"),
        .version = .{ .major = 0, .minor = 0, .patch = 1 },
    });

    lib.linkLibC();
    b.installArtifact(lib);
}
```

```ruby
# inotify.rb

require_relative 'ext/inotify/inotify'

path = ARGV.pop
unless path
  puts 'Error: A file path must be provided as an argument.'
  exit 1
end

Signal.trap('INT') do
  puts ''
  puts 'Exiting...'
  Inotify.rm_watch(@wd, @fd)
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
```

```ruby
# ext/inotify/inotify.rb

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'ffi'
end

module Inotify
  extend FFI::Library

  class Event < FFI::Struct
    layout :wd,     :int32,
           :mask,   :uint32,
           :cookie, :uint32,
           :len,    :uint32
  end

  ffi_lib FFI::Library::LIBC,
          File.join(File.dirname(__FILE__), 'lib', 'libinotify.so')

  attach_function :init, :inotify_init1, [:int], :int
  attach_function :add_watch, :inotify_add_watch, [:int, :string, :uint32], :int
  attach_function :rm_watch, :inotify_rm_watch, [:int, :uint32], :int

  callback :callback, [Event.by_ref, :string], :void
  attach_function :watch, [:int32, :callback], :int32

  module Flags
    # Flags taken from https://github.com/torvalds/linux/blob/master/include/uapi/linux/inotify.h
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
    IN_ALL_EVENTS = (IN_ACCESS | IN_MODIFY | IN_ATTRIB | IN_CLOSE_WRITE | \
                     IN_CLOSE_NOWRITE | IN_OPEN | IN_MOVED_FROM | \
                     IN_MOVED_TO | IN_DELETE | IN_CREATE | IN_DELETE_SELF | \
                     IN_MOVE_SELF)

    IN_NONBLOCK = 0000_4000
  end
end
```
