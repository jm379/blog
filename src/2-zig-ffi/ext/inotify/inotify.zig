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
