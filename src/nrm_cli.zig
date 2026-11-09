const std = @import("std");
const mem = std.mem;
const process = std.process;

const agent = @import("agent.zig");
const config_mod = @import("config.zig");
const guide = @import("guide.zig");
const help = @import("help.zig");
const host = @import("host.zig");
const i18n = @import("i18n.zig");
const messages = @import("messages.zig");
const registry = @import("registry.zig");
const util = @import("util.zig");

const ZnvmConfig = config_mod.ZnvmConfig;
const stderr = util.stderr;

fn writelnErr(msg: []const u8) void {
    stderr("{s}\n", .{msg}) catch {};
}

fn failMsg(comptime message: i18n.Msg, args: anytype) noreturn {
    var buf: [512]u8 = undefined;
    writelnErr(mem.trimEnd(u8, i18n.format(message, &buf, args), "\n"));
    process.exit(1);
}

fn failRaw(msg: []const u8) noreturn {
    writelnErr(msg);
    process.exit(1);
}

fn missingArg(name: []const u8) noreturn {
    failMsg(messages.nrm_error_missing_arg, .{name});
}

fn unknownCmd(cmd: []const u8) noreturn {
    failMsg(messages.nrm_error_unknown_command, .{cmd});
}

fn is(cmd: []const u8, names: []const []const u8) bool {
    for (names) |name| if (mem.eql(u8, cmd, name)) return true;
    return false;
}

fn mutating(_: mem.Allocator) void {
    agent.nrm_quiet_sync = true;
}

pub fn run(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    if (args.len < 2) {
        try help.printNrm();
        return;
    }
    const root = config.root_dir;
    if (is(args[1], &.{ "help", "--help", "-h" })) {
        if (args.len == 2) {
            try help.printNrm();
            return;
        }
        if (try help.printNrmCommand(args[2])) return;
        unknownCmd(args[2]);
    }
    if (args.len == 2 and is(args[1], &.{ "--version", "-v", "-V" })) return;
    if (args.len == 2 and mem.eql(u8, args[1], "lang")) {
        try util.stdout("{s}\n", .{i18n.code()});
        return;
    }
    if (args.len >= 2 and mem.eql(u8, args[1], "ls")) {
        if (args.len > 2 and !mem.eql(u8, args[2], "--json")) unknownCmd(args[2]);
        return registry.listNames(allocator, root);
    }
    if (mem.eql(u8, args[1], "list")) {
        if (args.len != 2) unknownCmd(args[2]);
        return registry.listNames(allocator, root);
    }
    if (mem.eql(u8, args[1], "current")) return tryCmdCurrent(allocator, args, root);
    if (mem.eql(u8, args[1], "use")) return tryCmdUse(allocator, args, root);
    if (mem.eql(u8, args[1], "add")) return tryCmdAdd(allocator, args, root);
    if (mem.eql(u8, args[1], "del") or mem.eql(u8, args[1], "rm")) return tryCmdDel(allocator, args, root);
    if (mem.eql(u8, args[1], "test")) return tryCmdTest(allocator, args, root);
    if (mem.eql(u8, args[1], "login")) return tryCmdLogin(allocator, args, root);
    if (mem.eql(u8, args[1], "set-hosted-repo")) return tryCmdSetHostedRepo(allocator, args, root);
    if (mem.eql(u8, args[1], "set-scope")) return tryCmdSetScope(allocator, args, root);
    if (mem.eql(u8, args[1], "del-scope")) return tryCmdDelScope(allocator, args, root);
    if (mem.eql(u8, args[1], "set")) return tryCmdSet(allocator, args, root);
    if (mem.eql(u8, args[1], "rename")) return tryCmdRename(allocator, args, root);
    if (mem.eql(u8, args[1], "home")) return tryCmdHome(allocator, args, root);
    if (mem.eql(u8, args[1], "scope")) return tryCmdScope(allocator, args, root);
    unknownCmd(args[1]);
}

fn tryCmdCurrent(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    if (args.len == 2) return registry.current(allocator, root, false);
    if (args.len == 3 and is(args[2], &.{ "-u", "--show-url" })) return registry.current(allocator, root, true);
    unknownCmd(if (args.len >= 3) args[2] else args[1]);
}

fn tryCmdUse(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    mutating(allocator);
    var verbose = false;
    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (is(args[i], &.{ "--verbose", "-v" })) {
            verbose = true;
            continue;
        }
        break;
    }
    if (verbose) agent.nrm_verbose_sync = true;
    const rest = args[i..];
    if (rest.len == 0) {
        if (!host.isTty(.stdin())) missingArg("name");
        const names = try registry.listRegistryLabels(allocator, root);
        defer registry.freeLabels(allocator, names);
        const pick = try guide.pickOne(allocator, "Please select the registry you want to use", "请选择要使用的源", names);
        if (pick) |index| {
            try registry.useName(allocator, root, names[index]);
            return;
        }
        return;
    }
    if (rest.len == 1 and mem.eql(u8, rest[0], "auto")) return registry.useAuto(allocator, root);
    if (rest.len == 1) return registry.useName(allocator, root, rest[0]);
    unknownCmd(if (rest.len >= 1) rest[0] else args[1]);
}

fn tryCmdAdd(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    mutating(allocator);
    if (args.len == 4) return registry.addName(allocator, root, args[2], args[3]);
    if (args.len == 5) return registry.addNameWithHome(allocator, root, args[2], args[3], args[4]);
    if (args.len < 4) {
        if (args.len == 2) missingArg("name");
        missingArg("url");
    }
    unknownCmd(args[2]);
}

fn tryCmdDel(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    mutating(allocator);
    if (args.len == 3) return registry.delName(allocator, root, args[2]);
    if (args.len != 2) unknownCmd(if (args.len >= 3) args[2] else args[1]);
    if (!host.isTty(.stdin())) missingArg("name");
    const names = try registry.listCustomLabels(allocator, root);
    defer registry.freeLabels(allocator, names);
    if (names.len == 0) failMsg(messages.nrm_no_custom_del, .{});
    const pick = try guide.pickOne(allocator, "Please select the registries you want to delete", "请选择要删除的源", names);
    const index = pick orelse return;
    try registry.delName(allocator, root, names[index]);
}

fn tryCmdTest(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    if (args.len == 2) return registry.testRegistries(allocator, root, null);
    if (args.len == 3 and !mem.eql(u8, args[2], "--json")) return registry.testRegistries(allocator, root, args[2]);
    if (args.len == 3 and mem.eql(u8, args[2], "--json")) return registry.testRegistries(allocator, root, null);
    unknownCmd(if (args.len >= 3) args[2] else args[1]);
}

fn tryCmdLogin(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    mutating(allocator);
    if (args.len < 3) missingArg("name");
    const name = args[2];
    var always_auth = false;
    var username: ?[]const u8 = null;
    var password: ?[]const u8 = null;
    var email: ?[]const u8 = null;
    var base64: ?[]const u8 = null;
    var i: usize = 3;
    if (i < args.len and args[i][0] != '-') {
        base64 = args[i];
        i += 1;
    }
    while (i < args.len) : (i += 1) {
        if (mem.eql(u8, args[i], "-a") or mem.eql(u8, args[i], "--always-auth")) {
            always_auth = true;
        } else if (i + 1 < args.len and (mem.eql(u8, args[i], "-u") or mem.eql(u8, args[i], "--username"))) {
            username = args[i + 1];
            i += 1;
        } else if (i + 1 < args.len and (mem.eql(u8, args[i], "-p") or mem.eql(u8, args[i], "--password"))) {
            password = args[i + 1];
            i += 1;
        } else if (i + 1 < args.len and (mem.eql(u8, args[i], "-e") or mem.eql(u8, args[i], "--email"))) {
            email = args[i + 1];
            i += 1;
        } else {
            unknownCmd(args[2]);
        }
    }
    try registry.loginRegistry(allocator, root, name, .{
        .base64 = base64,
        .username = username,
        .password = password,
        .email = email,
        .always_auth = if (always_auth) true else null,
    });
}

fn tryCmdSetHostedRepo(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    mutating(allocator);
    if (args.len != 4) {
        if (args.len < 3) missingArg("name");
        missingArg("repo");
    }
    try registry.setHostedRepo(allocator, root, args[2], args[3]);
}

fn tryCmdSetScope(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    mutating(allocator);
    if (args.len != 4) {
        if (args.len < 3) missingArg("scopeName");
        missingArg("url");
    }
    try registry.setScopeNrm(allocator, root, args[2], args[3]);
}

fn tryCmdDelScope(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    mutating(allocator);
    if (args.len != 3) missingArg("scopeName");
    try registry.delScopeNrm(allocator, root, args[2]);
}

fn tryCmdSet(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    mutating(allocator);
    if (args.len < 3) missingArg("name");
    var attr: ?[]const u8 = null;
    var value: ?[]const u8 = null;
    var i: usize = 3;
    while (i < args.len) : (i += 1) {
        if (i + 1 < args.len and (mem.eql(u8, args[i], "-a") or mem.eql(u8, args[i], "--attr"))) {
            attr = args[i + 1];
            i += 1;
        } else if (i + 1 < args.len and (mem.eql(u8, args[i], "-v") or mem.eql(u8, args[i], "--value"))) {
            value = args[i + 1];
            i += 1;
        } else {
            unknownCmd(args[2]);
        }
    }
    const a = attr orelse missingArg("attr");
    const v = value orelse missingArg("value");
    try registry.setAttr(allocator, root, args[2], a, v);
}

fn tryCmdRename(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    mutating(allocator);
    if (args.len != 4) {
        if (args.len < 3) missingArg("name");
        missingArg("newName");
    }
    try registry.renameName(allocator, root, args[2], args[3]);
}

fn tryCmdHome(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    if (args.len < 3) missingArg("name");
    const browser = if (args.len >= 4) args[3] else null;
    try registry.openHome(allocator, root, args[2], browser);
}

fn tryCmdScope(allocator: mem.Allocator, args: []const []const u8, root: []const u8) !void {
    if (args.len < 3) unknownCmd("scope");
    const sub = args[2];
    if (is(sub, &.{ "ls", "list" }) and args.len == 3) return registry.listScopes(allocator, root);
    if (mem.eql(u8, sub, "add") and args.len == 5) {
        mutating(allocator);
        return registry.add(allocator, root, args[3], args[4]);
    }
    if (is(sub, &.{ "del", "rm" }) and args.len == 4) {
        mutating(allocator);
        return registry.removeScope(allocator, root, args[3]);
    }
    unknownCmd(sub);
}
