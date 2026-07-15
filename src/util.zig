const std = @import("std");

pub fn stdout(comptime fmt: []const u8, args: anytype) !void {
    var buf: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buf);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

pub fn stderr(comptime fmt: []const u8, args: anytype) !void {
    var buf: [8192]u8 = undefined;
    var writer = std.fs.File.stderr().writer(&buf);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}
