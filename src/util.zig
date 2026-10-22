const std = @import("std");

pub fn stdout(comptime fmt: []const u8, args: anytype) !void {
    // Streaming: a positional writer restarts at offset 0, so a second print
    // would overwrite a redirected file instead of appending.
    var buf: [8192]u8 = undefined;
    var writer = std.fs.File.stdout().writerStreaming(&buf);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

pub fn stderr(comptime fmt: []const u8, args: anytype) !void {
    var buf: [8192]u8 = undefined;
    var writer = std.fs.File.stderr().writerStreaming(&buf);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}
