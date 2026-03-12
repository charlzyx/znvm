const std = @import("std");
const mem = std.mem;
const process = std.process;
const heap = std.heap;

const util = @import("util.zig");
const config_mod = @import("config.zig");
const commands = @import("commands.zig");

const stdout = util.stdout;
const stderr = util.stderr;

const ZNVM_VERSION = "v2.0.0-rc.1";

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage(args[0]);
        process.exit(1);
    }

    const cmd = args[1];
    const config = try config_mod.getConfig(allocator);
    defer config.deinit();

    if (mem.eql(u8, cmd, "env")) {
        try commands.cmdEnv(allocator, args, config);
    } else if (mem.eql(u8, cmd, "use")) {
        try commands.cmdUse(allocator, args, config);
    } else if (mem.eql(u8, cmd, "install")) {
        try commands.cmdInstall(allocator, args, config);
    } else if (mem.eql(u8, cmd, "ls") or mem.eql(u8, cmd, "list")) {
        try commands.cmdList(allocator, args, config);
    } else if (mem.eql(u8, cmd, "uninstall") or mem.eql(u8, cmd, "rm")) {
        try commands.cmdUninstall(allocator, args, config);
    } else if (mem.eql(u8, cmd, "default")) {
        try commands.cmdDefault(allocator, args, config);
    } else if (mem.eql(u8, cmd, "version") or mem.eql(u8, cmd, "--version") or mem.eql(u8, cmd, "-v")) {
        try stdout("{s}\n", .{ZNVM_VERSION});
    } else {
        try stderr("Unknown command: {s}\n", .{cmd});
        printUsage(args[0]);
        process.exit(1);
    }
}

fn printUsage(exe_name: []const u8) void {
    stdout("znvm {s}\n", .{ZNVM_VERSION}) catch {};
    stdout("Usage: {s} <command> [args...]\n", .{exe_name}) catch {};
    stdout("\nCommands:\n", .{}) catch {};
    stdout("  env [shell]     Generate shell configuration (eval \"$({s} env)\")\n", .{exe_name}) catch {};
    stdout("  install <ver>   Install a specific version\n", .{}) catch {};
    stdout("  use <ver>       Switch to a version (outputs shell commands)\n", .{}) catch {};
    stdout("  list, ls        List installed versions\n", .{}) catch {};
    stdout("  uninstall, rm   Uninstall a version\n", .{}) catch {};
    stdout("  default <ver>   Set default version\n", .{}) catch {};
    stdout("  version         Show znvm version\n", .{}) catch {};
}
