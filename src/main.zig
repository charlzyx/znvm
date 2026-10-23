const std = @import("std");
const mem = std.mem;
const process = std.process;

const util = @import("util.zig");
const config_mod = @import("config.zig");
const commands = @import("commands.zig");
const guide = @import("guide.zig");
const host = @import("host.zig");
const i18n = @import("i18n.zig");

const stdout = util.stdout;
const stderr = util.stderr;

const ZNVM_VERSION = "v2.8.3";
const agent = @import("agent.zig");

fn writeToolVersion(allocator: mem.Allocator) !void {
    if (!agent.json_mode) {
        try stdout("{s}\n", .{ZNVM_VERSION});
        return;
    }
    var sink = agent.Sink.init(allocator);
    defer sink.deinit();
    try sink.beginObject();
    try sink.fieldString("version", ZNVM_VERSION);
    try sink.endObject();
    try sink.flush();
}

pub fn main(init: process.Init.Minimal) !void {
    host.bind(init);
    const allocator = std.heap.c_allocator;
    i18n.init(allocator);

    const raw_args = try init.args.toSlice(allocator);
    defer allocator.free(raw_args);
    const flags = try agent.strip(allocator, raw_args);
    defer allocator.free(flags.argv);
    const args = flags.argv;
    agent.json_mode = flags.json;
    agent.yes_mode = flags.yes;
    if (flags.llm) {
        try agent.writeSkill();
        return;
    }

    const base_name = std.fs.path.basename(args[0]);
    const invoked_as_nvm = mem.eql(u8, base_name, "nvm");
    const invoked_as_nrm = mem.eql(u8, base_name, "nrm");
    commands.program_name = if (invoked_as_nrm) "nrm" else if (invoked_as_nvm) "nvm" else "znvm";

    const config = try config_mod.getConfig(allocator);
    defer config.deinit();

    if (invoked_as_nrm) {
        if (args.len < 2) {
            if (agent.json_mode) agent.fail(1, "error: --json needs a command.");
            if (agent.menuAllowed(.stdout)) {
                try guide.runNrm(allocator, config);
            } else {
                try commands.printNrmHelp();
            }
            return;
        }
        if (agent.json_mode and !agent.jsonSupported(true, args)) {
            agent.fail(1, "error: --json is not supported for this command.");
        }
        const nrm_cmd = args[1];
        if ((mem.eql(u8, nrm_cmd, "--version") or mem.eql(u8, nrm_cmd, "-v")) and args.len == 2) {
            try writeToolVersion(allocator);
            return;
        }
        try commands.cmdNrm(allocator, args, config);
        return;
    }

    // Node commands only. use, ls, and current here never switch a registry.

    if (args.len < 2) {
        if (agent.json_mode) agent.fail(1, "error: --json needs a command.");
        try guide.run(allocator, config, .session);
        return;
    }

    const cmd = args[1];
    if (agent.json_mode and !agent.jsonSupported(false, args)) {
        agent.fail(1, "error: --json is not supported for this command.");
    }

    if (mem.eql(u8, cmd, "guide") or mem.eql(u8, cmd, "interactive")) {
        try guide.run(allocator, config, .session);
        return;
    } else if (mem.eql(u8, cmd, "--guide-step")) {
        try guide.run(allocator, config, .step);
        return;
    } else if (mem.eql(u8, cmd, "lang") and args.len == 2) {
        try stdout("{s}\n", .{i18n.code()});
    } else if (mem.eql(u8, cmd, "help") or mem.eql(u8, cmd, "--help") or mem.eql(u8, cmd, "-h")) {
        try commands.cmdHelp(args);
    } else if (mem.eql(u8, cmd, "--version") or mem.eql(u8, cmd, "-v")) {
        try writeToolVersion(allocator);
    } else if (mem.eql(u8, cmd, "version") and args.len == 2 and !invoked_as_nvm) {
        try writeToolVersion(allocator);
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
    } else if (mem.eql(u8, cmd, "reinstall-packages") or mem.eql(u8, cmd, "copy-packages")) {
        try commands.cmdReinstallPackages(allocator, args, config);
    } else if (mem.eql(u8, cmd, "install-latest-npm")) {
        try commands.cmdInstallLatestNpm(allocator, args, config);
    } else if (mem.eql(u8, cmd, "cache") or mem.eql(u8, cmd, "clear-cache")) {
        try commands.cmdCache(allocator, args, config);
    } else if (mem.eql(u8, cmd, "registry")) {
        try commands.cmdRegistry(allocator, args, config);
    } else if (mem.eql(u8, cmd, "mirror")) {
        try commands.cmdMirror(allocator, args, config);
    } else if (mem.eql(u8, cmd, "debug")) {
        try commands.cmdDebug(allocator, config);
    } else {
        try @import("help.zig").unknownCommand(cmd);
        try commands.printHelp();
        process.exit(1);
    }
}
