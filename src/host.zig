//! Process-wide `std.Io` for the 0.17 standard library.
//!
//! Ordinary commands use the single-threaded Io instance so startup stays a
//! couple of assignments. `beginThreads` switches to `Io.Threaded` only while
//! mirror probes spawn curl in parallel.
const std = @import("std");
const builtin = @import("builtin");

pub const EnvMap = std.process.Environ.Map;

var threaded: std.Io.Threaded = undefined;
var threaded_ready = false;
var saved_args: std.process.Args = undefined;

pub fn bind(minimal: std.process.Init.Minimal) void {
    saved_args = minimal.args;
}

pub fn beginThreads(gpa: std.mem.Allocator) void {
    if (comptime builtin.is_test) return;
    if (threaded_ready) return;
    threaded = .init(gpa, .{
        .argv0 = .init(saved_args),
        .environ = environ(),
    });
    threaded_ready = true;
}

pub fn endThreads() void {
    if (comptime builtin.is_test) return;
    if (!threaded_ready) return;
    threaded.deinit();
    threaded_ready = false;
}

pub fn io() std.Io {
    if (comptime builtin.is_test) return std.testing.io;
    if (threaded_ready) return threaded.io();
    return std.Io.Threaded.global_single_threaded.io();
}

fn liveEnviron() std.process.Environ {
    var n: usize = 0;
    while (std.c.environ[n] != null) : (n += 1) {}
    const many: [*:null]const ?[*:0]const u8 = @ptrCast(std.c.environ);
    return .{ .block = .{ .slice = many[0..n :null] } };
}

pub fn environ() std.process.Environ {
    if (comptime builtin.is_test) return std.testing.environ;
    return liveEnviron();
}

pub fn envMap(allocator: std.mem.Allocator) !EnvMap {
    return std.process.Environ.createMap(environ(), allocator);
}

pub fn realpathAlloc(allocator: std.mem.Allocator, path: []const u8) ![:0]u8 {
    if (std.fs.path.isAbsolute(path)) {
        return std.Io.Dir.realPathFileAbsoluteAlloc(io(), path, allocator);
    }
    return std.Io.Dir.cwd().realPathFileAlloc(io(), path, allocator);
}

pub fn cwdPath(allocator: std.mem.Allocator) ![:0]u8 {
    return std.Io.Dir.cwd().realPathFileAlloc(io(), ".", allocator);
}

pub fn deleteTreeAbsolute(path: []const u8) !void {
    try std.Io.Dir.cwd().deleteTree(io(), path);
}

pub fn readToEndAlloc(file: std.Io.File, allocator: std.mem.Allocator, max: usize) ![]u8 {
    var buf: [8192]u8 = undefined;
    var reader = file.readerStreaming(io(), &buf);
    return reader.interface.allocRemaining(allocator, .limited(max));
}

pub fn writeAll(file: std.Io.File, bytes: []const u8) !void {
    try file.writeStreamingAll(io(), bytes);
}

pub fn isTty(file: std.Io.File) bool {
    return file.isTty(io()) catch false;
}

pub fn unixSeconds() i64 {
    return std.Io.Timestamp.now(io(), .real).toSeconds();
}

pub fn getenv(key: [:0]const u8) ?[:0]const u8 {
    const value = std.c.getenv(key) orelse return null;
    return std.mem.span(value);
}

pub fn run(allocator: std.mem.Allocator, argv: []const []const u8, limit: usize) !std.process.RunResult {
    // Spawning needs an allocator inside `Io.Threaded`. The single-threaded
    // instance uses a failing allocator, so switch before the first child.
    beginThreads(allocator);
    return std.process.run(allocator, io(), .{
        .argv = argv,
        .stdout_limit = .limited(limit),
        .stderr_limit = .limited(limit),
        .create_no_window = false,
    });
}

pub const Stdio = enum { inherit, ignore };

pub fn spawnWait(argv: []const []const u8, env_map: ?*const EnvMap, stdout_mode: Stdio) !std.process.Child.Term {
    beginThreads(std.heap.c_allocator);
    var child = try std.process.spawn(io(), .{
        .argv = argv,
        .environ_map = env_map,
        .stdin = .inherit,
        .stdout = switch (stdout_mode) {
            .inherit => .inherit,
            .ignore => .ignore,
        },
        .stderr = .inherit,
        .create_no_window = false,
    });
    return child.wait(io());
}
