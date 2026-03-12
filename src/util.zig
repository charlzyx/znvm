const std = @import("std");

pub fn stdout(comptime fmt: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    const writer = &w.interface;
    try writer.print(fmt, args);
    try writer.flush();
}

pub fn stderr(comptime fmt: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    const writer = &w.interface;
    try writer.print(fmt, args);
    try writer.flush();
}
