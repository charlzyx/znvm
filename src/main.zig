const std = @import("std");
const mem = std.mem;
const process = std.process;
const heap = std.heap;

const util = @import("util.zig");
const config_mod = @import("config.zig");
const commands = @import("commands.zig");

const stdout = util.stdout;
const stderr = util.stderr;

const ZNVM_VERSION = "v2.2.2";

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    const invoked_as_nvm = mem.eql(u8, std.fs.path.basename(args[0]), "nvm");
    commands.program_name = if (invoked_as_nvm) "nvm" else "znvm";

    if (args.len < 2) {
        try commands.printHelp();
        process.exit(1);
    }

    const cmd = args[1];
    const config = try config_mod.getConfig(allocator);
    defer config.deinit();

    if (mem.eql(u8, cmd, "help") or mem.eql(u8, cmd, "--help") or mem.eql(u8, cmd, "-h")) {
        try commands.printHelp();
    } else if (mem.eql(u8, cmd, "--version") or mem.eql(u8, cmd, "-v")) {
        try stdout("{s}\n", .{ZNVM_VERSION});
    } else if (mem.eql(u8, cmd, "version") and args.len == 2 and !invoked_as_nvm) {
        try stdout("{s}\n", .{ZNVM_VERSION});
    } else if (mem.eql(u8, cmd, "env")) {
        try commands.cmdEnv(allocator, args, config);
    } else if (mem.eql(u8, cmd, "use")) {
        try commands.cmdUse(allocator, args, config);
    } else if (mem.eql(u8, cmd, "install")) {
        try commands.cmdInstall(allocator, args, config);
    } else if (mem.eql(u8, cmd, "ls") or mem.eql(u8, cmd, "list")) {
        try commands.cmdList(allocator, args, config);
    } else if (mem.eql(u8, cmd, "ls-remote") or mem.eql(u8, cmd, "list-remote")) {
        try commands.cmdListRemote(allocator, args, config);
    } else if (mem.eql(u8, cmd, "uninstall") or mem.eql(u8, cmd, "rm")) {
        try commands.cmdUninstall(allocator, args, config);
    } else if (mem.eql(u8, cmd, "default")) {
        try commands.cmdDefault(allocator, args, config);
    } else if (mem.eql(u8, cmd, "alias")) {
        try commands.cmdAlias(allocator, args, config);
    } else if (mem.eql(u8, cmd, "unalias")) {
        try commands.cmdUnalias(allocator, args, config);
    } else if (mem.eql(u8, cmd, "current")) {
        try commands.cmdCurrent(allocator, args, config);
    } else if (mem.eql(u8, cmd, "which")) {
        try commands.cmdWhich(allocator, args, config);
    } else if (mem.eql(u8, cmd, "version")) {
        try commands.cmdVersion(allocator, args, config);
    } else if (mem.eql(u8, cmd, "version-remote")) {
        try commands.cmdVersionRemote(allocator, args, config);
    } else if (mem.eql(u8, cmd, "exec")) {
        try commands.cmdExec(allocator, args, config);
    } else if (mem.eql(u8, cmd, "run")) {
        try commands.cmdRun(allocator, args, config);
    } else if (mem.eql(u8, cmd, "deactivate")) {
        try commands.cmdDeactivate(allocator, args, config);
    } else {
        try stderr("Unknown command: {s}\n", .{cmd});
        try commands.printHelp();
        process.exit(1);
    }
}
