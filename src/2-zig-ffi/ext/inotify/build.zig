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
