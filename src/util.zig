const std = @import("std");

pub fn stdout(comptime fmt: []const u8, args: anytype) !void {
    var buf: [8192]u8 = undefined;
    const str = try std.fmt.bufPrint(&buf, fmt, args);
    _ = try std.fs.File.stdout().write(str);
}

pub fn stderr(comptime fmt: []const u8, args: anytype) !void {
    var buf: [8192]u8 = undefined;
    const str = try std.fmt.bufPrint(&buf, fmt, args);
    _ = try std.fs.File.stderr().write(str);
}
