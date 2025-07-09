---
title: Zig FFI
date: 2025-07-01
description: How to create a dynamic shared library with Zig and use it in Ruby
---

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

Zig is a capable systems language that introduces many features focused on safety, error handling,
and explicit memory management, along with an excellent build system and great interoperability with C.

## File system events

In many applications that require tracking updates of the file system in real-time, developers can use
the polling method to check for file changes. This method involves repeatedly querying a file's last
modified/accessed/changed timestamps using the [stat API](https://www.man7.org/linux/man-pages/man2/stat.2.html),
which can be inefficient and resource-intensive since it's a system call.

Fortunately, [Inotify](https://www.man7.org/linux/man-pages/man7/inotify.7.html) is a more efficient
solution that was introduced in the Linux kernel 2.6.13, allowing programs to monitor file
system events such as modifications, deletions, and creations without the need for constant polling.
This feature provides immediate notifications of file changes, enabling applications to respond
instantly and reducing overall system load.

### Codify

To illustrate how can we use Zig to create a Ruby extension, we are going to write an Inotify library
to watch all events occurred on a path provided to the application.

To start, let's create all the needed files and directories.

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

Now, let's start with the `ext/inotify/inotify.zig`

```zig
// ext/inotify/inotify.zig

const std = @import("std");
const posix = std.posix;
const InotifyEvent = std.os.linux.inotify_event;
// Importing the Inotify C header
const inotify = @cImport(@cInclude("sys/inotify.h"));

// Define a callback type for handling Inotify events
const Callback = *const fn (event: *InotifyEvent, name: [*:0]const u8) callconv(.C) void;

// The watch function sets up an Inotify watch and processes events
export fn watch(fd: i32, cb: Callback) callconv(.C) i32 {
    // Buffer to hold the Inotify event data, sized to accommodate the maximum event size
    var buff: [@sizeOf(InotifyEvent) + posix.PATH_MAX:0]u8 align(@alignOf(InotifyEvent)) = undefined;
    var read: usize = undefined; // Variable to store the number of bytes read
    var idx: usize = 0; // Index for traversing the event buffer
    var event: *InotifyEvent = undefined; // Pointer to the current Inotify event

    // Read from the Inotify file descriptor
    read = posix.read(fd, &buff) catch |err| {
        return switch (err) {
            error.WouldBlock => -1, // Non-blocking read would block
            else => -2, // Other errors
        };
    };

    // Process each event in the buffer
    while (idx < read) {
        // Cast the buffer slice to an InotifyEvent pointer
        event = @ptrCast(@alignCast(buff[idx..read]));
        idx += @sizeOf(InotifyEvent) + event.len; // Move the index to the next event
        // Get the name of the file associated with the event
        // Inotify event may not have a name
        const name = event.getName() orelse ""; 
        cb(event, name); // Call the provided callback with the event and file name
    }
    return 0; // Return success
}
```

#### Key Points of the `ext/inotify/inotify.zig` File:

1. **Imports and Constants:** The program imports necessary Zig standard libraries and POSIX functions, as
well as the Inotify event structure from the Linux headers. This sets up the environment for working with
Inotify.

2. **Callback Definition:** A callback type is defined, which will be used to handle Inotify events. This
allows the user of the `watch` function to specify custom behavior when an event occurs.

3. **Buffer Allocation:** A buffer is allocated to hold the Inotify event data. The size is determined by
the maximum size of an Inotify event plus the maximum path length, ensuring that the buffer can
accommodate any event.

4. **Reading Events:** The `posix.read` function is called to read data from the Inotify file descriptor.
Error handling is implemented to manage cases where the read operation would block or other errors occur.

5. **Event Processing Loop:** A loop processes each event in the buffer. The index is updated to move to
the next event, and the event name is retrieved using the `getName()` method. The callback is then invoked
with the event and its associated file name.

6. **Return Value:** The function returns 0 on success, indicating that the events were processed without
issues.

```zig
// ext/inotify/build.zig

const std = @import("std");

// The build function is the entry point for building the shared library
pub fn build(b: *std.Build) void {
    // Retrieve standard target options based on the current build environment
    const target = b.standardTargetOptions(.{});
    // Retrieve standard optimization options for the build
    const optimize = b.standardOptimizeOption(.{});
    
    // Create a shared library named "inotify"
    const lib = b.addSharedLibrary(.{
        .name = "inotify", // Name of the shared library
        .optimize = optimize, // Optimization level for the build
        .target = target, // Target architecture and platform
        .root_source_file = b.path("inotify.zig"), // Path to the main source file
        .version = .{ .major = 0, .minor = 0, .patch = 1 }, // Versioning information
    });

    // Link the C standard library to the shared library
    lib.linkLibC();
    // Install the built shared library artifact
    b.installArtifact(lib);
}
```
#### Key Points of the `ext/inotify/build.zig` File:

1. **Standard Library Import:** The script begins by importing the Zig standard library, which provides
essential functions and types for building the project.

2. **Build Function:** The `build` function serves as the entry point for the build process. It takes a
pointer to the `std.Build` structure, which contains methods and properties for configuring the build.

3. **Target and Optimization Options:** The script retrieves standard target options and optimization
settings based on the current build environment. This ensures that the library is built appropriately for
the intended platform and with the desired performance characteristics.

4. **Shared Library Creation:** The `addSharedLibrary` method is called to create a shared library. Key
parameters include:
    - **Name:** The name of the library (`"inotify"`).
    - **Optimization:** The optimization level determined earlier.
    - **Target:** The target architecture and platform.
    - **Root Source File:** The path to the main source file (`inotify.zig`).
    - **Versioning:** The version of the library, specified with major, minor, and patch numbers.

5. **Linking C Standard Library:** The `linkLibC` method is called to link the C standard library with
the shared library. This is necessary for using C functions and types within the Zig code.

6. **Installing the Artifact:** Finally, the `installArtifact` method is called to install the built
shared library, making it available for use in other projects or applications.

#### Building the shared library

# TODO: 
- Write how to build the zig library

```ruby
# ext/inotify/inotify.rb

require 'bundler/inline'

# Use inline Bundler to manage dependencies, specifically the
# 'ffi' gem for foreign function interface
gemfile do
  source 'https://rubygems.org'

  gem 'ffi'
end

module Inotify
  extend FFI::Library

  # Define a structure to represent an Inotify event
  class Event < FFI::Struct
    layout :wd,     :int32,     # Watch descriptor
           :mask,   :uint32,    # Event mask
           :cookie, :uint32,    # Cookie for identifying related event
           :len,    :uint32     # Length of the name field
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
    IN_ALL_EVENTS = (IN_ACCESS | IN_MODIFY | IN_ATTRIB | IN_CLOSE_WRITE | \
                     IN_CLOSE_NOWRITE | IN_OPEN | IN_MOVED_FROM | \
                     IN_MOVED_TO | IN_DELETE | IN_CREATE | IN_DELETE_SELF | \
                     IN_MOVE_SELF)

    IN_NONBLOCK = 0000_4000 # Non-blocking flag
  end
end
```

#### Key Points of the `ext/inotify/inotify.rb` File:


1. **Dependency Management:** The script uses Bundler to manage the `ffi` gem, which allows for interfacing
with C libraries.

2. **Event Structure Definition:** A class `Event` is defined using `FFI::Struct` to represent an Inotify 
event, including fields for the watch descriptor, event mask, cookie, and length of the name.

3. **Library Loading:** The script loads the C standard library and the shared Inotify library created by Zig
using `ffi_lib`.

4. **Function Attachments:** Functions from the Inotify shared library are attached, allowing Ruby to call
these C functions for initializing Inotify, adding and removing watches.

5. **Callback Definition:** A callback type is defined for handling Inotify events, allowing users to specify
custom behavior when an event occurs.

6. **Event Flags:** A module `Flags` is defined, containing constants for various Inotify event types and
flags, based on the Linux kernel definitions. This includes flags for file access, modification,
creation, deletion, and special behaviors.

7. **Convenience Aggregation:** The `IN_ALL_EVENTS` constant aggregates all event flags for convenience,
making it easier to specify multiple events when setting up watches.

```ruby
# inotify.rb

# Require the Inotify interface defined in the ext/inotify/inotify file
require_relative 'ext/inotify/inotify'

# Get the file path from command-line arguments
path = ARGV.pop
# Check if a path was provided; if not, print an error and exit
unless path
  puts 'Error: A file path must be provided as an argument.'
  exit 1
end

# Set up a signal trap for the INT signal (Ctrl+C) to handle graceful termination
Signal.trap('INT') do
  puts ''
  puts 'Exiting...'
  # Remove the watch on the file descriptor before exiting
  Inotify.rm_watch(@wd, @fd)
  @io.close
  exit
end

# Inform the user that the specified path is being watched
puts "Watching for Inotify events in `#{path}'"
puts 'Press ctrl-C to exit'

# Initialize Inotify and create a non-blocking file descriptor
@fd = Inotify.init(Inotify::Flags::IN_NONBLOCK)
# Creating an IO object from the Inotify file descriptor, so it can be closed at exit
@io = IO.new @fd
# Add a watch on the specified path for all Inotify events
@wd = Inotify.add_watch(@fd, path, Inotify::Flags::IN_ALL_EVENTS)

# Start an infinite loop to continuously check for Inotify events
loop do
  # Call the watch method, which will invoke the provided block for each event
  Inotify.watch(@fd) do |event, name|
    # Print details about the event, including the watch descriptor, event mask,
    # cookie, length of the name, and the name of the affected file
    puts "wd: #{event[:wd]}, mask: #{event[:mask].to_s(16)}, cookie: #{event[:cookie]}, len: #{event[:len]}, name: #{name}"
  end
end
```

#### Key Points of the `inotify.rb` File:

1. **Require Inotify Interface:** The script starts by requiring the Inotify interface defined in the
`ext/inotify/inotify` file, which provides access to the Inotify functionality.

2. **Command-Line Argument Handling:** It retrieves the last argument from the command line as the path to
be monitored. If no path is provided, it prints an error message and exits with a non-zero status.

3. **Signal Trap for Graceful Exit:** A signal trap is set up to handle the `INT` signal (triggered by pressing
`Ctrl+C`). When this signal is received, it prints a message, removes the watch on the file descriptor,
and exits the program cleanly.

4. **User Feedback:** The script informs the user that it is watching the specified path and prompts them to 
press `Ctrl+C` to exit.

5. **Inotify Initialization:** It initializes Inotify and creates a non-blocking file descriptor, allowing the
program to continue running without being blocked by read operations.

6. **Adding a Watch:** The script adds a watch on the specified path for all Inotify events, storing the
watch descriptor for later use.

7. **Event Loop:** An infinite loop is started to continuously check for Inotify events. Inside the loop,
the `Inotify.watch` method is called, which invokes the provided block for each event detected.

8. **Event Details Output:** For each event, the script prints detailed information, including the watch
descriptor, event mask (converted to hexadecimal), cookie, length of the name, and the name of the
affected file.


# TODO: 
- Show what events are emitted when creating a file with touch
- Show where in the touch source code each event was created (https://github.com/coreutils/coreutils/blob/master/src/touch.c)


# TODO:
- Write a conclusion
