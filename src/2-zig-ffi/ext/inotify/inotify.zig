const std = @import("std");
const posix = std.posix;
const InotifyEvent = std.os.linux.inotify_event;
const inotify = @cImport(@cInclude("sys/inotify.h"));

const Callback = *const fn (wd: i32, mask: u32, cookie: u32, len: u32, name: [*:0]const u8) callconv(.C) void;

export fn watch(fd: i32, cb: Callback) callconv(.C) void {
    var buff: [@sizeOf(InotifyEvent) + posix.PATH_MAX:0]u8 align(@alignOf(InotifyEvent)) = undefined;
    var read: usize = undefined;
    var idx: usize = 0;
    var event: *InotifyEvent = undefined;

    while (true) {
        read = posix.read(fd, &buff) catch {
            return;
        };

        while (idx < read) {
            event = @ptrCast(@alignCast(buff[idx..read]));
            idx += @sizeOf(InotifyEvent) + event.len;
            if (event.getName()) |name| {
                cb(event.wd, event.mask, event.cookie, event.len, name);
            } else {
                cb(event.wd, event.mask, event.cookie, event.len, "");
            }
        }
        idx = 0;
    }
}

export fn init() i32 {
    return posix.inotify_init1(0) catch {
        return 0;
    };
}

export fn add_watch(fd: i32, pathname: [*:0]u8, mask: u32) i32 {
    return posix.inotify_add_watchZ(fd, pathname, mask) catch {
        return 0;
    };
}

export fn rm_watch(fd: i32, wd: i32) void {
    posix.close(wd);
    return posix.inotify_rm_watch(fd, wd);
}
