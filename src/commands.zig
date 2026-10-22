const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const util = @import("util.zig");
const version = @import("version.zig");
const ZnvmConfig = @import("config.zig").ZnvmConfig;

const stdout = util.stdout;
const stderr = util.stderr;

pub var program_name: []const u8 = "znvm";

const LocalHit = union(enum) {
    version: []u8,
    system: void,

    fn deinit(self: LocalHit, allocator: mem.Allocator) void {
        switch (self) {
            .version => |owned| allocator.free(owned),
            .system => {},
        }
    }
};

const ParsedArgs = struct {
    silent: bool = false,
    lts: ?[]const u8 = null,
    set_default: bool = false,
    alias_to: ?[]const u8 = null,
    no_alias: bool = false,
    positionals: std.ArrayList([]const u8) = .{},

    fn deinit(self: *ParsedArgs, allocator: mem.Allocator) void {
        self.positionals.deinit(allocator);
    }
};

const FlagMode = enum { strict, command };

fn shellQuote(allocator: mem.Allocator, value: []const u8) ![]u8 {
    var quoted = std.ArrayList(u8){};
    errdefer quoted.deinit(allocator);

    try quoted.append(allocator, '\'');
    for (value) |char| {
        if (char == '\'') {
            try quoted.appendSlice(allocator, "'\\''");
        } else {
            try quoted.append(allocator, char);
        }
    }
    try quoted.append(allocator, '\'');
    return quoted.toOwnedSlice(allocator);
}

fn versionsPrefix(allocator: mem.Allocator, config: ZnvmConfig) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/", .{config.versions_dir});
}

fn managedVersionFromRealPath(allocator: mem.Allocator, config: ZnvmConfig, real_path: []const u8) !?[]u8 {
    const prefix = try versionsPrefix(allocator, config);
    defer allocator.free(prefix);
    if (!mem.startsWith(u8, real_path, prefix)) return null;
    const after = real_path[prefix.len..];
    const end = mem.indexOfScalar(u8, after, '/') orelse return null;
    if (end == 0) return null;
    return try allocator.dupe(u8, after[0..end]);
}

fn pathEntries(allocator: mem.Allocator) !?[]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();
    const path_env = env_map.get("PATH") orelse return null;
    return try allocator.dupe(u8, path_env);
}

fn getCurrentVersionFromPath(allocator: mem.Allocator, config: ZnvmConfig) !?[]u8 {
    const path_env_owned = try pathEntries(allocator) orelse return null;
    defer allocator.free(path_env_owned);

    var it = mem.splitScalar(u8, path_env_owned, ':');
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        const node_path = try fs.path.join(allocator, &.{ dir, "node" });
        defer allocator.free(node_path);
        fs.accessAbsolute(node_path, .{}) catch continue;
        const real_path = std.fs.realpathAlloc(allocator, node_path) catch continue;
        defer allocator.free(real_path);
        if (try managedVersionFromRealPath(allocator, config, real_path)) |ver| return ver;
    }
    return null;
}

fn findSystemNode(allocator: mem.Allocator, config: ZnvmConfig) !?[]u8 {
    const path_env_owned = try pathEntries(allocator) orelse return null;
    defer allocator.free(path_env_owned);

    var it = mem.splitScalar(u8, path_env_owned, ':');
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        const node_path = try fs.path.join(allocator, &.{ dir, "node" });
        defer allocator.free(node_path);
        fs.accessAbsolute(node_path, .{}) catch continue;
        const real_path = std.fs.realpathAlloc(allocator, node_path) catch continue;
        errdefer allocator.free(real_path);
        if (try managedVersionFromRealPath(allocator, config, real_path)) |ver| {
            allocator.free(ver);
            allocator.free(real_path);
            continue;
        }
        return real_path;
    }
    return null;
}

fn pathWithVersion(allocator: mem.Allocator, config: ZnvmConfig, ver: []const u8, current_path: []const u8) ![]u8 {
    const bin_path = try fs.path.join(allocator, &.{ config.versions_dir, ver, "bin" });
    defer allocator.free(bin_path);
    const npm_bin_path = try fs.path.join(allocator, &.{ config.npm_prefix, "bin" });
    defer allocator.free(npm_bin_path);
    const prefix = try versionsPrefix(allocator, config);
    defer allocator.free(prefix);

    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    try list.appendSlice(allocator, npm_bin_path);
    try list.append(allocator, ':');
    try list.appendSlice(allocator, bin_path);

    var it = mem.splitScalar(u8, current_path, ':');
    while (it.next()) |entry| {
        if (entry.len == 0) continue;
        if (mem.startsWith(u8, entry, prefix) or mem.eql(u8, entry, npm_bin_path) or mem.eql(u8, entry, bin_path)) continue;
        try list.append(allocator, ':');
        try list.appendSlice(allocator, entry);
    }
    return list.toOwnedSlice(allocator);
}

fn pathWithoutVersions(allocator: mem.Allocator, config: ZnvmConfig, current_path: []const u8) ![]u8 {
    const prefix = try versionsPrefix(allocator, config);
    defer allocator.free(prefix);

    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    var it = mem.splitScalar(u8, current_path, ':');
    while (it.next()) |entry| {
        if (entry.len == 0 or mem.startsWith(u8, entry, prefix)) continue;
        if (list.items.len > 0) try list.append(allocator, ':');
        try list.appendSlice(allocator, entry);
    }
    return list.toOwnedSlice(allocator);
}

fn currentPath(allocator: mem.Allocator) ![]u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();
    return allocator.dupe(u8, env_map.get("PATH") orelse "");
}

fn emitExports(allocator: mem.Allocator, config: ZnvmConfig, ver: []const u8, silent: bool) !void {
    const node_bin = try fs.path.join(allocator, &.{ config.versions_dir, ver, "bin", "node" });
    defer allocator.free(node_bin);
    fs.accessAbsolute(node_bin, .{}) catch {
        try stderr("Version '{s}' is installed but bin/node is missing.\n", .{ver});
        process.exit(1);
    };

    const path = try currentPath(allocator);
    defer allocator.free(path);
    const new_path = try pathWithVersion(allocator, config, ver, path);
    defer allocator.free(new_path);
    const bin_path = try fs.path.join(allocator, &.{ config.versions_dir, ver, "bin" });
    defer allocator.free(bin_path);
    const inc_path = try fs.path.join(allocator, &.{ config.versions_dir, ver, "include", "node" });
    defer allocator.free(inc_path);

    const quoted_path = try shellQuote(allocator, new_path);
    defer allocator.free(quoted_path);
    const quoted_version = try shellQuote(allocator, ver);
    defer allocator.free(quoted_version);
    const quoted_prefix = try shellQuote(allocator, config.npm_prefix);
    defer allocator.free(quoted_prefix);
    const quoted_bin = try shellQuote(allocator, bin_path);
    defer allocator.free(quoted_bin);
    const quoted_inc = try shellQuote(allocator, inc_path);
    defer allocator.free(quoted_inc);

    try stdout("export PATH={s}\n", .{quoted_path});
    try stdout("export ZNVM_CURRENT={s}\n", .{quoted_version});
    try stdout("export NPM_CONFIG_PREFIX={s}\n", .{quoted_prefix});
    try stdout("export NVM_BIN={s}\n", .{quoted_bin});
    try stdout("export NVM_INC={s}\n", .{quoted_inc});
    try stdout("hash -r 2>/dev/null || true\n", .{});
    if (!silent) try stderr("Using {s}\n", .{ver});
}

fn emitDeactivate(allocator: mem.Allocator, config: ZnvmConfig, silent: bool, message: []const u8) !void {
    const path = try currentPath(allocator);
    defer allocator.free(path);
    const new_path = try pathWithoutVersions(allocator, config, path);
    defer allocator.free(new_path);
    const quoted_path = try shellQuote(allocator, new_path);
    defer allocator.free(quoted_path);

    try stdout("export PATH={s}\n", .{quoted_path});
    try stdout("unset ZNVM_CURRENT\n", .{});
    try stdout("unset NVM_BIN\n", .{});
    try stdout("unset NVM_INC\n", .{});
    try stdout("hash -r 2>/dev/null || true\n", .{});
    if (!silent and message.len > 0) try stderr("{s}\n", .{message});
}

fn ensureDir(path: []const u8) !void {
    fs.makeDirAbsolute(path) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
}

fn validAliasName(name: []const u8) bool {
    if (name.len == 0 or name.len > 128) return false;
    if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) return false;
    if (name[0] == '-' or name[0] == '.') return false;
    for (name) |char| {
        if (char == '/' or char == '\\' or char == ':' or std.ascii.isWhitespace(char)) return false;
    }
    return true;
}

fn aliasFilePath(allocator: mem.Allocator, config: ZnvmConfig, name: []const u8) ![]u8 {
    return fs.path.join(allocator, &.{ config.root_dir, "alias", name });
}

fn readSmallFile(allocator: mem.Allocator, path: []const u8) !?[]u8 {
    const file = fs.openFileAbsolute(path, .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 8192);
    const trimmed = mem.trim(u8, content, " \t\n\r");
    if (trimmed.len == 0) {
        allocator.free(content);
        return null;
    }
    const owned = try allocator.dupe(u8, trimmed);
    allocator.free(content);
    return owned;
}

fn readAlias(allocator: mem.Allocator, config: ZnvmConfig, name: []const u8) !?[]u8 {
    if (!validAliasName(name)) return null;
    const path = try aliasFilePath(allocator, config, name);
    defer allocator.free(path);
    if (try readSmallFile(allocator, path)) |target| return target;
    if (mem.eql(u8, name, "default")) {
        const legacy = try fs.path.join(allocator, &.{ config.root_dir, "default" });
        defer allocator.free(legacy);
        return readSmallFile(allocator, legacy);
    }
    return null;
}

fn setAlias(allocator: mem.Allocator, config: ZnvmConfig, name: []const u8, target: []const u8) !void {
    if (!validAliasName(name)) {
        try stderr("Alias name '{s}' is invalid.\n", .{name});
        process.exit(1);
    }
    if (target.len == 0 or mem.indexOfScalar(u8, target, '\n') != null) {
        try stderr("Alias target is invalid.\n", .{});
        process.exit(1);
    }
    try ensureDir(config.root_dir);
    const alias_dir = try fs.path.join(allocator, &.{ config.root_dir, "alias" });
    defer allocator.free(alias_dir);
    try ensureDir(alias_dir);

    const path = try aliasFilePath(allocator, config, name);
    defer allocator.free(path);
    {
        const file = try fs.createFileAbsolute(path, .{});
        defer file.close();
        try file.writeAll(target);
    }

    if (mem.eql(u8, name, "default")) {
        const legacy = try fs.path.join(allocator, &.{ config.root_dir, "default" });
        defer allocator.free(legacy);
        const file = try fs.createFileAbsolute(legacy, .{});
        defer file.close();
        try file.writeAll(target);
    }
}

fn deleteAlias(allocator: mem.Allocator, config: ZnvmConfig, name: []const u8) !bool {
    if (!validAliasName(name)) return false;
    var removed = false;
    const path = try aliasFilePath(allocator, config, name);
    defer allocator.free(path);
    if (fs.deleteFileAbsolute(path)) {
        removed = true;
    } else |err| {
        if (err != error.FileNotFound) return err;
    }
    if (mem.eql(u8, name, "default")) {
        const legacy = try fs.path.join(allocator, &.{ config.root_dir, "default" });
        defer allocator.free(legacy);
        if (fs.deleteFileAbsolute(legacy)) {
            removed = true;
        } else |err| {
            if (err != error.FileNotFound) return err;
        }
    }
    return removed;
}

const AliasRecord = struct {
    name: []u8,
    target: []u8,
};

fn loadAliases(allocator: mem.Allocator, config: ZnvmConfig) ![]AliasRecord {
    var list = std.ArrayList(AliasRecord){};
    errdefer {
        for (list.items) |item| {
            allocator.free(item.name);
            allocator.free(item.target);
        }
        list.deinit(allocator);
    }

    const alias_dir = try fs.path.join(allocator, &.{ config.root_dir, "alias" });
    defer allocator.free(alias_dir);
    var saw_default = false;

    if (fs.openDirAbsolute(alias_dir, .{ .iterate = true })) |dir_open| {
        var dir = dir_open;
        defer dir.close();
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file or !validAliasName(entry.name)) continue;
            const target = try readAlias(allocator, config, entry.name) orelse continue;
            errdefer allocator.free(target);
            const name = try allocator.dupe(u8, entry.name);
            errdefer allocator.free(name);
            if (mem.eql(u8, name, "default")) saw_default = true;
            try list.append(allocator, .{ .name = name, .target = target });
        }
    } else |err| {
        if (err != error.FileNotFound) return err;
    }

    if (!saw_default) {
        if (try readAlias(allocator, config, "default")) |target| {
            errdefer allocator.free(target);
            const name = try allocator.dupe(u8, "default");
            errdefer allocator.free(name);
            try list.append(allocator, .{ .name = name, .target = target });
        }
    }

    const Sorter = struct {
        fn less(_: void, lhs: AliasRecord, rhs: AliasRecord) bool {
            return mem.lessThan(u8, lhs.name, rhs.name);
        }
    };
    mem.sort(AliasRecord, list.items, {}, Sorter.less);
    return list.toOwnedSlice(allocator);
}

fn freeAliases(allocator: mem.Allocator, aliases: []AliasRecord) void {
    for (aliases) |item| {
        allocator.free(item.name);
        allocator.free(item.target);
    }
    allocator.free(aliases);
}

fn printAliases(allocator: mem.Allocator, config: ZnvmConfig, pattern: ?[]const u8) !bool {
    const aliases = try loadAliases(allocator, config);
    defer freeAliases(allocator, aliases);
    var any = false;
    for (aliases) |item| {
        if (pattern) |prefix| {
            if (!mem.startsWith(u8, item.name, prefix)) continue;
        }
        try stdout("{s} -> {s}\n", .{ item.name, item.target });
        any = true;
    }
    return any;
}

fn rejectUnsupportedSpec(spec: []const u8) !void {
    if (mem.eql(u8, spec, "iojs") or mem.eql(u8, spec, "unstable") or mem.startsWith(u8, spec, "iojs-") or mem.startsWith(u8, spec, "iojs/")) {
        try stderr("{s} does not manage io.js or the historical \"unstable\" line.\n", .{program_name});
        process.exit(1);
    }
}

fn freeInstalled(allocator: mem.Allocator, installed: []const []const u8) void {
    for (installed) |item| allocator.free(item);
    allocator.free(installed);
}

fn resolveLocalSpec(allocator: mem.Allocator, config: ZnvmConfig, spec: []const u8, lts_flag: ?[]const u8, depth: u8) !?LocalHit {
    if (depth > 8) return error.AliasCycle;
    const query = version.parseVersionQuery(spec, lts_flag);

    switch (query.special) {
        .system => return .{ .system = {} },
        .current => {
            const current = try getCurrentVersionFromPath(allocator, config) orelse return null;
            return .{ .version = current };
        },
        .default => {
            const target = try readAlias(allocator, config, "default") orelse return null;
            defer allocator.free(target);
            return resolveLocalSpec(allocator, config, target, null, depth + 1);
        },
        .latest, .none => {},
    }

    if (query.lts != null) {
        const remote = try version.resolveRemoteQuery(allocator, query, config) orelse return null;
        defer allocator.free(remote.version);
        defer allocator.free(remote.filename);
        const installed = try version.getInstalledVersions(allocator, config);
        defer freeInstalled(allocator, installed);
        const exact = version.findExactInstalled(installed, remote.version) orelse return null;
        return .{ .version = try allocator.dupe(u8, exact) };
    }

    if (query.special == .latest) {
        const installed = try version.getInstalledVersions(allocator, config);
        defer freeInstalled(allocator, installed);
        const best = version.latestInstalled(installed, query.prefix) orelse return null;
        return .{ .version = try allocator.dupe(u8, best) };
    }

    const installed = try version.getInstalledVersions(allocator, config);
    defer freeInstalled(allocator, installed);
    if (version.findExactInstalled(installed, spec)) |exact| {
        return .{ .version = try allocator.dupe(u8, exact) };
    }
    if (validAliasName(spec)) {
        if (try readAlias(allocator, config, spec)) |target| {
            defer allocator.free(target);
            return resolveLocalSpec(allocator, config, target, null, depth + 1);
        }
    }
    const resolved = try version.resolveLocalVersion(allocator, installed, spec) orelse return null;
    return .{ .version = try allocator.dupe(u8, resolved) };
}

fn resolveLocalOrExit(allocator: mem.Allocator, config: ZnvmConfig, spec: []const u8, lts_flag: ?[]const u8) !LocalHit {
    const hit = resolveLocalSpec(allocator, config, spec, lts_flag, 0) catch |err| switch (err) {
        error.AliasCycle => {
            try stderr("The alias \"{s}\" leads to an infinite loop. Aborting.\n", .{spec});
            process.exit(8);
        },
        else => return err,
    };
    return hit orelse {
        try stderr("Version '{s}' is not installed. Run '{s} install {s}' first.\n", .{ spec, program_name, spec });
        process.exit(1);
    };
}

fn findNvmrc(allocator: mem.Allocator) !?[]u8 {
    var dir = try fs.cwd().realpathAlloc(allocator, ".");
    while (true) {
        const candidate = try fs.path.join(allocator, &.{ dir, ".nvmrc" });
        if (fs.accessAbsolute(candidate, .{})) |_| {
            allocator.free(dir);
            return candidate;
        } else |_| {
            allocator.free(candidate);
        }

        const parent_slice = fs.path.dirname(dir) orelse {
            allocator.free(dir);
            return null;
        };
        if (mem.eql(u8, parent_slice, dir)) {
            allocator.free(dir);
            return null;
        }
        const parent = try allocator.dupe(u8, parent_slice);
        allocator.free(dir);
        dir = parent;
    }
}

fn readNvmrcSpec(allocator: mem.Allocator, silent: bool) !?[]u8 {
    const path = try findNvmrc(allocator) orelse return null;
    defer allocator.free(path);
    const content = try readSmallFile(allocator, path) orelse {
        try stderr("invalid .nvmrc: {s}\n", .{path});
        process.exit(1);
    };
    defer allocator.free(content);
    const spec = version.parseNvmrc(content) orelse {
        try stderr("invalid .nvmrc: {s}\n", .{path});
        process.exit(1);
    };
    if (!silent) try stderr("Found '{s}' with version <{s}>\n", .{ path, spec });
    return try allocator.dupe(u8, spec);
}

fn consumeFlag(parsed: *ParsedArgs, arg: []const u8) !bool {
    if (mem.eql(u8, arg, "--silent")) {
        parsed.silent = true;
        return true;
    }
    if (mem.eql(u8, arg, "--lts")) {
        parsed.lts = "*";
        return true;
    }
    if (mem.startsWith(u8, arg, "--lts=")) {
        const name = arg["--lts=".len..];
        if (name.len == 0) {
            try stderr("Option \"--lts=\" needs an LTS name.\n", .{});
            process.exit(55);
        }
        parsed.lts = name;
        return true;
    }
    if (mem.eql(u8, arg, "--default")) {
        parsed.set_default = true;
        return true;
    }
    if (mem.startsWith(u8, arg, "--alias=")) {
        const name = arg["--alias=".len..];
        if (name.len == 0) {
            try stderr("Option \"--alias=\" needs a name.\n", .{});
            process.exit(55);
        }
        parsed.alias_to = name;
        return true;
    }
    if (mem.eql(u8, arg, "--no-colors")) return true;
    if (mem.eql(u8, arg, "--no-alias")) {
        parsed.no_alias = true;
        return true;
    }
    if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
        try printHelp();
        process.exit(0);
    }
    if (mem.eql(u8, arg, "-s") or mem.eql(u8, arg, "-b") or mem.startsWith(u8, arg, "--reinstall-packages-from") or mem.eql(u8, arg, "--latest-npm") or mem.eql(u8, arg, "--offline") or mem.eql(u8, arg, "--save") or mem.eql(u8, arg, "--skip-default-packages") or mem.eql(u8, arg, "--no-progress")) {
        try stderr("Option \"{s}\" is not supported by {s}.\n", .{ arg, program_name });
        process.exit(55);
    }
    return false;
}

fn parseArgs(allocator: mem.Allocator, args: []const []const u8, mode: FlagMode) !ParsedArgs {
    var parsed = ParsedArgs{};
    errdefer parsed.deinit(allocator);
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (mem.eql(u8, arg, "--")) {
            index += 1;
            while (index < args.len) : (index += 1) try parsed.positionals.append(allocator, args[index]);
            break;
        }
        if (mem.startsWith(u8, arg, "-") and parsed.positionals.items.len == 0) {
            if (try consumeFlag(&parsed, arg)) continue;
            if (mode == .command) {
                while (index < args.len) : (index += 1) try parsed.positionals.append(allocator, args[index]);
                break;
            }
            try stderr("Unsupported option \"{s}\".\n", .{arg});
            process.exit(55);
        }
        try parsed.positionals.append(allocator, arg);
        if (mode == .command) {
            index += 1;
            while (index < args.len) : (index += 1) try parsed.positionals.append(allocator, args[index]);
            break;
        }
    }
    return parsed;
}

fn ltsSpec(allocator: mem.Allocator, name: []const u8) ![]u8 {
    if (name.len == 0 or mem.eql(u8, name, "*")) return allocator.dupe(u8, "lts/*");
    return std.fmt.allocPrint(allocator, "lts/{s}", .{name});
}

fn isVersionSelector(allocator: mem.Allocator, config: ZnvmConfig, token: []const u8) !bool {
    if (mem.eql(u8, token, "iojs") or mem.eql(u8, token, "unstable") or mem.startsWith(u8, token, "iojs-")) return true;
    if (version.looksLikeVersion(token)) return true;
    if (validAliasName(token)) {
        if (try readAlias(allocator, config, token)) |target| {
            allocator.free(target);
            return true;
        }
    }
    return false;
}

fn applyHit(allocator: mem.Allocator, config: ZnvmConfig, hit: LocalHit, silent: bool, system_message: []const u8) !void {
    switch (hit) {
        .system => try emitDeactivate(allocator, config, silent, system_message),
        .version => |ver| try emitExports(allocator, config, ver, silent),
    }
}

fn siblingExe(allocator: mem.Allocator, name: []const u8) ![]u8 {
    const self_path = std.fs.selfExePathAlloc(allocator) catch return allocator.dupe(u8, name);
    defer allocator.free(self_path);
    const dir = fs.path.dirname(self_path) orelse ".";
    return fs.path.join(allocator, &.{ dir, name });
}

pub fn printHelp() !void {
    try stdout(
        \\{s} — fast Node.js version manager
        \\
        \\Version selectors: 20, 20.11, v20.11.0, node, stable, lts/*, lts/<name>, default, current, system
        \\.nvmrc is read from the current directory and its parents. '#' comments are ignored.
        \\
        \\Commands:
        \\  install [version] [--lts] [--lts=<name>] [--default] [--alias=<name>]
        \\  use [version] [--lts] [--silent]
        \\  exec [version] <command> [args...]
        \\  run [version] [node args...]
        \\  ls, list [version] [--no-alias]
        \\  ls-remote, list-remote [version] [--lts]
        \\  current
        \\  which [version]
        \\  version [version]          nvm: active or resolved version; znvm with no args: tool version
        \\  version-remote [version]
        \\  alias [name [target]]
        \\  unalias <name>
        \\  default [version]          same as: alias default [version]
        \\  uninstall, rm <version>
        \\  deactivate [--silent]
        \\  env                        shell setup (eval "$({s} env)")
        \\  --version, -v              print the znvm version
        \\  help, --help
        \\
        \\Not supported: source builds (-s), io.js, --reinstall-packages-from, --latest-npm,
        \\--offline, color themes, and per-version global npm packages.
        \\Node binaries are downloaded from $ZNVM_NODE_MIRROR or $NVM_NODEJS_ORG_MIRROR
        \\(default https://npmmirror.com/mirrors/node). Versions live in $ZNVM_DIR (default ~/.znvm).
        \\
    , .{ program_name, program_name });
}

pub fn cmdEnv(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    _ = args;
    const root_dir = try shellQuote(allocator, config.root_dir);
    defer allocator.free(root_dir);
    const npm_prefix = try shellQuote(allocator, config.npm_prefix);
    defer allocator.free(npm_prefix);
    const npm_bin_path = try fs.path.join(allocator, &.{ config.npm_prefix, "bin" });
    defer allocator.free(npm_bin_path);
    const path = try currentPath(allocator);
    defer allocator.free(path);

    var path_list = std.ArrayList(u8){};
    defer path_list.deinit(allocator);
    try path_list.appendSlice(allocator, npm_bin_path);
    var path_it = mem.splitScalar(u8, path, ':');
    while (path_it.next()) |entry| {
        if (entry.len == 0 or mem.eql(u8, entry, npm_bin_path)) continue;
        try path_list.append(allocator, ':');
        try path_list.appendSlice(allocator, entry);
    }
    const path_value = try shellQuote(allocator, path_list.items);
    defer allocator.free(path_value);

    const znvm_exe_raw = try siblingExe(allocator, "znvm");
    defer allocator.free(znvm_exe_raw);
    const nvm_exe_raw = try siblingExe(allocator, "nvm");
    defer allocator.free(nvm_exe_raw);
    const znvm_exe = try shellQuote(allocator, znvm_exe_raw);
    defer allocator.free(znvm_exe);
    const nvm_exe = try shellQuote(allocator, nvm_exe_raw);
    defer allocator.free(nvm_exe);

    const shell_script =
        \\# znvm shell setup
        \\export ZNVM_DIR={s}
        \\export NPM_CONFIG_PREFIX={s}
        \\export PATH={s}
        \\
        \\__znvm_exe={s}
        \\__nvm_exe={s}
        \\if [ ! -x "$__nvm_exe" ]; then
        \\  __nvm_exe="$__znvm_exe"
        \\fi
        \\
        \\__znvm_apply() {{
        \\  local bin="$1"
        \\  shift
        \\  local result
        \\  local exit_code
        \\  result="$("$bin" "$@")"
        \\  exit_code=$?
        \\  if [ "$exit_code" -eq 0 ]; then
        \\    if [ -n "$result" ]; then
        \\      eval "$result"
        \\    fi
        \\  else
        \\    if [ -n "$result" ]; then
        \\      printf '%s\n' "$result" >&2
        \\    fi
        \\    return "$exit_code"
        \\  fi
        \\}}
        \\
        \\__znvm_dispatch() {{
        \\  local bin="$1"
        \\  shift
        \\  case "${{1-}}" in
        \\    use|install|uninstall|rm|deactivate)
        \\      __znvm_apply "$bin" "$@"
        \\      ;;
        \\    *)
        \\      "$bin" "$@"
        \\      ;;
        \\  esac
        \\}}
        \\
        \\znvm() {{
        \\  __znvm_dispatch "$__znvm_exe" "$@"
        \\}}
        \\
        \\nvm() {{
        \\  if [ "${{1-}}" = "version" ] && [ "$#" -eq 1 ]; then
        \\    __znvm_dispatch "$__nvm_exe" current
        \\    return
        \\  fi
        \\  __znvm_dispatch "$__nvm_exe" "$@"
        \\}}
        \\
        \\__znvm_autoload() {{
        \\  local result
        \\  if result="$("$__znvm_exe" use --silent 2>/dev/null)"; then
        \\    [ -n "$result" ] && eval "$result"
        \\  elif result="$("$__znvm_exe" use --silent default 2>/dev/null)"; then
        \\    [ -n "$result" ] && eval "$result"
        \\  fi
        \\}}
        \\
        \\__znvm_on_chdir() {{
        \\  if [ "${{PWD-}}" = "${{ZNVM_LAST_PWD-}}" ]; then
        \\    return 0
        \\  fi
        \\  ZNVM_LAST_PWD="${{PWD-}}"
        \\  __znvm_autoload
        \\}}
        \\
        \\if [ -n "${{ZSH_VERSION-}}" ]; then
        \\  autoload -U add-zsh-hook 2>/dev/null || true
        \\  add-zsh-hook chpwd __znvm_on_chdir 2>/dev/null || true
        \\elif [ -n "${{BASH_VERSION-}}" ]; then
        \\  case ";${{PROMPT_COMMAND-}};" in
        \\    *";__znvm_on_chdir;"*) ;;
        \\    *) PROMPT_COMMAND="__znvm_on_chdir${{PROMPT_COMMAND:+;$PROMPT_COMMAND}}" ;;
        \\  esac
        \\fi
        \\
        \\__znvm_autoload
        \\ZNVM_LAST_PWD="${{PWD-}}"
        \\
    ;
    try stdout(shell_script, .{ root_dir, npm_prefix, path_value, znvm_exe, nvm_exe });
}

fn requireSpec(allocator: mem.Allocator, parsed: *const ParsedArgs, usage: []const u8, silent: bool) ![]u8 {
    if (parsed.positionals.items.len > 1) {
        try stderr("{s}\n", .{usage});
        process.exit(1);
    }
    if (parsed.lts) |name| return ltsSpec(allocator, name);
    if (parsed.positionals.items.len == 1) return allocator.dupe(u8, parsed.positionals.items[0]);
    return try readNvmrcSpec(allocator, silent) orelse {
        try stderr("{s}\nNo .nvmrc file found.\n", .{usage});
        process.exit(127);
    };
}

pub fn cmdUse(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    const usage = try std.fmt.allocPrint(allocator, "Usage: {s} use [version]", .{program_name});
    defer allocator.free(usage);
    const spec = try requireSpec(allocator, &parsed, usage, parsed.silent);
    defer allocator.free(spec);
    try rejectUnsupportedSpec(spec);
    const hit = try resolveLocalOrExit(allocator, config, spec, null);
    defer hit.deinit(allocator);
    try applyHit(allocator, config, hit, parsed.silent, "Using system Node.js");
}

fn resolveInstallSpec(allocator: mem.Allocator, config: ZnvmConfig, spec: []const u8, lts_flag: ?[]const u8, depth: u8) !?version.ResolvedRemote {
    if (depth > 8) return error.AliasCycle;
    const query = version.parseVersionQuery(spec, lts_flag);
    switch (query.special) {
        .system => {
            try stderr("The system Node.js cannot be installed with {s}.\n", .{program_name});
            process.exit(1);
        },
        .current => {
            const current = try getCurrentVersionFromPath(allocator, config) orelse {
                try stderr("No active Node.js version.\n", .{});
                process.exit(1);
            };
            defer allocator.free(current);
            return version.resolveRemoteQuery(allocator, version.parseVersionQuery(current, null), config);
        },
        .default => {
            const target = try readAlias(allocator, config, "default") orelse {
                try stderr("No default version set.\n", .{});
                process.exit(1);
            };
            defer allocator.free(target);
            return resolveInstallSpec(allocator, config, target, null, depth + 1);
        },
        .latest, .none => {
            if (query.special == .none and query.lts == null and validAliasName(spec)) {
                if (try readAlias(allocator, config, spec)) |target| {
                    defer allocator.free(target);
                    return resolveInstallSpec(allocator, config, target, null, depth + 1);
                }
            }
            return version.resolveRemoteQuery(allocator, query, config);
        },
    }
}

fn aliasTargetIsUsable(allocator: mem.Allocator, config: ZnvmConfig, target: []const u8) !void {
    const query = version.parseVersionQuery(target, null);
    if (query.special == .latest or query.special == .system or query.special == .current or query.lts != null) return;
    const hit = resolveLocalSpec(allocator, config, target, null, 0) catch |err| switch (err) {
        error.AliasCycle => {
            try stderr("The alias \"{s}\" leads to an infinite loop. Aborting.\n", .{target});
            process.exit(8);
        },
        else => return err,
    };
    if (hit) |resolved| {
        resolved.deinit(allocator);
        return;
    }
    try stderr("Version '{s}' is not installed. Run '{s} install {s}' first.\n", .{ target, program_name, target });
    process.exit(1);
}

pub fn cmdInstall(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    const usage = try std.fmt.allocPrint(allocator, "Usage: {s} install [version]", .{program_name});
    defer allocator.free(usage);
    const spec = try requireSpec(allocator, &parsed, usage, parsed.silent);
    defer allocator.free(spec);
    try rejectUnsupportedSpec(spec);

    const resolved = resolveInstallSpec(allocator, config, spec, null, 0) catch |err| switch (err) {
        error.AliasCycle => {
            try stderr("The alias \"{s}\" leads to an infinite loop. Aborting.\n", .{spec});
            process.exit(8);
        },
        else => return err,
    } orelse {
        try stderr("Could not resolve version '{s}'\n", .{spec});
        process.exit(1);
    };
    defer allocator.free(resolved.version);
    defer allocator.free(resolved.filename);
    const ver = resolved.version;

    const install_path = try fs.path.join(allocator, &.{ config.versions_dir, ver });
    defer allocator.free(install_path);
    const already = if (fs.accessAbsolute(install_path, .{})) true else |err| switch (err) {
        error.FileNotFound => false,
        else => return err,
    };
    if (already) {
        if (!parsed.silent) try stderr("Version {s} is already installed.\n", .{ver});
    } else {
        if (!parsed.silent) try stderr("Installing {s} ({s})...\n", .{ ver, resolved.arch });
        const download_url = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ config.mirror, ver, resolved.filename });
        defer allocator.free(download_url);
        const tar_path = try fs.path.join(allocator, &.{ config.root_dir, resolved.filename });
        defer allocator.free(tar_path);
        try ensureDir(config.root_dir);
        try version.downloadFile(allocator, download_url, tar_path);
        if (!parsed.silent) try stderr("Extracting...\n", .{});
        try ensureDir(config.versions_dir);
        try ensureDir(install_path);

        const argv = &[_][]const u8{ "tar", "-xzf", tar_path, "-C", install_path, "--strip-components=1" };
        var child = process.Child.init(argv, allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Inherit;
        const term = try child.spawnAndWait();
        const extracted = switch (term) {
            .Exited => |code| code == 0,
            else => false,
        };
        if (!extracted) {
            try stderr("Extraction failed.\n", .{});
            fs.deleteTreeAbsolute(install_path) catch {};
            process.exit(1);
        }
        fs.deleteFileAbsolute(tar_path) catch {};
        if (!parsed.silent) try stderr("Installed {s}\n", .{ver});
    }

    const existing_default = try readAlias(allocator, config, "default");
    defer if (existing_default) |value| allocator.free(value);
    if (parsed.set_default or existing_default == null) {
        try setAlias(allocator, config, "default", ver);
        if (!parsed.silent) try stderr("default -> {s}\n", .{ver});
    }
    if (parsed.alias_to) |name| {
        try setAlias(allocator, config, name, ver);
        if (!parsed.silent) try stderr("{s} -> {s}\n", .{ name, ver });
    }

    try emitExports(allocator, config, ver, parsed.silent);
}

pub fn cmdList(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len > 1) {
        try stderr("Usage: {s} ls [version]\n", .{program_name});
        process.exit(1);
    }
    if (parsed.no_alias and parsed.positionals.items.len > 0) {
        try stderr("`--no-alias` is not supported when a version is provided.\n", .{});
        process.exit(55);
    }

    const installed = try version.getInstalledVersions(allocator, config);
    defer freeInstalled(allocator, installed);
    const current = try getCurrentVersionFromPath(allocator, config);
    defer if (current) |value| allocator.free(value);

    var shown: usize = 0;
    if (parsed.positionals.items.len == 1) {
        const pattern = parsed.positionals.items[0];
        const query = version.parseVersionQuery(pattern, parsed.lts);
        if (query.prefix.len > 0 and query.special == .none and query.lts == null) {
            for (installed) |ver| {
                if (ver.len < 2 or ver[0] != 'v') continue;
                if (!version.matchesVersionPrefix(ver[1..], query.prefix)) continue;
                try printVersionLine(ver, current);
                shown += 1;
            }
        } else if (resolveLocalSpec(allocator, config, pattern, parsed.lts, 0) catch null) |hit| {
            defer hit.deinit(allocator);
            switch (hit) {
                .version => |ver| {
                    try printVersionLine(ver, current);
                    shown += 1;
                },
                .system => {
                    try stdout("system\n", .{});
                    shown += 1;
                },
            }
        }
        if (shown == 0) {
            try stdout("N/A\n", .{});
            process.exit(3);
        }
        return;
    }

    if (installed.len == 0) {
        try stdout("No versions installed.\n", .{});
    } else {
        for (installed) |ver| try printVersionLine(ver, current);
    }
    if (!parsed.no_alias) _ = try printAliases(allocator, config, null);
}

fn printVersionLine(ver: []const u8, current: ?[]const u8) !void {
    const is_current = if (current) |active| mem.eql(u8, active, ver) else false;
    if (is_current) {
        try stdout("->     {s}\n", .{ver});
    } else {
        try stdout("       {s}\n", .{ver});
    }
}

pub fn cmdListRemote(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len > 1) {
        try stderr("Usage: {s} ls-remote [version]\n", .{program_name});
        process.exit(1);
    }
    const raw = if (parsed.positionals.items.len == 1) parsed.positionals.items[0] else "";
    var query = version.parseVersionQuery(raw, parsed.lts);
    if (query.special == .current or query.special == .system or query.special == .default) {
        try stdout("N/A\n", .{});
        process.exit(3);
    }
    if (query.special == .latest) query.special = .none;
    const list_all = query.special == .none and query.lts == null and query.prefix.len == 0;

    const index = version.loadRemoteIndex(allocator, config) catch |err| {
        try stderr("Failed to fetch Node.js index ({s})\n", .{@errorName(err)});
        process.exit(1);
    };
    defer index.deinit();

    var matched = std.ArrayList(version.NodeEntry){};
    defer matched.deinit(allocator);
    for (index.value) |entry| {
        if (!version.isInstallable(entry, config.os, config.arch)) continue;
        if (!list_all and !version.entryMatchesQuery(entry, query)) continue;
        if (entry.version.len < 2 or entry.version[0] != 'v') continue;
        _ = std.SemanticVersion.parse(entry.version[1..]) catch continue;
        try matched.append(allocator, entry);
    }
    if (matched.items.len == 0) {
        try stdout("N/A\n", .{});
        process.exit(3);
    }
    const Sorter = struct {
        fn less(_: void, lhs: version.NodeEntry, rhs: version.NodeEntry) bool {
            const left = std.SemanticVersion.parse(lhs.version[1..]) catch return false;
            const right = std.SemanticVersion.parse(rhs.version[1..]) catch return true;
            return left.order(right) == .lt;
        }
    };
    mem.sort(version.NodeEntry, matched.items, {}, Sorter.less);
    for (matched.items) |entry| {
        if (version.entryLtsName(entry)) |name| {
            try stdout("{s}    (LTS: {s})\n", .{ entry.version, name });
        } else {
            try stdout("{s}\n", .{entry.version});
        }
    }
}

pub fn cmdUninstall(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len != 1 and parsed.lts == null) {
        try stderr("Usage: {s} uninstall <version>\n", .{program_name});
        process.exit(1);
    }
    const spec = if (parsed.lts) |name| try ltsSpec(allocator, name) else try allocator.dupe(u8, parsed.positionals.items[0]);
    defer allocator.free(spec);
    try rejectUnsupportedSpec(spec);
    const hit = try resolveLocalOrExit(allocator, config, spec, null);
    defer hit.deinit(allocator);
    switch (hit) {
        .system => {
            try stderr("The system Node.js cannot be uninstalled with {s}.\n", .{program_name});
            process.exit(1);
        },
        .version => |ver| {
            const active = try getCurrentVersionFromPath(allocator, config);
            defer if (active) |value| allocator.free(value);
            const path = try fs.path.join(allocator, &.{ config.versions_dir, ver });
            defer allocator.free(path);
            try fs.deleteTreeAbsolute(path);
            try stderr("Uninstalled {s}\n", .{ver});
            if (active) |value| {
                if (mem.eql(u8, value, ver)) try emitDeactivate(allocator, config, true, "");
            }
        },
    }
}

pub fn cmdAlias(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len > 2) {
        try stderr("Usage: {s} alias [name [target]]\n", .{program_name});
        process.exit(1);
    }
    if (parsed.positionals.items.len == 2) {
        const name = parsed.positionals.items[0];
        const target = parsed.positionals.items[1];
        try rejectUnsupportedSpec(target);
        try aliasTargetIsUsable(allocator, config, target);
        try setAlias(allocator, config, name, target);
        try stderr("{s} -> {s}\n", .{ name, target });
        return;
    }
    const pattern = if (parsed.positionals.items.len == 1) parsed.positionals.items[0] else null;
    if (!try printAliases(allocator, config, pattern)) {
        if (pattern) |_| {
            try stderr("No alias found.\n", .{});
            process.exit(1);
        }
    }
}

pub fn cmdUnalias(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len != 1) {
        try stderr("Usage: {s} unalias <name>\n", .{program_name});
        process.exit(1);
    }
    const name = parsed.positionals.items[0];
    if (!try deleteAlias(allocator, config, name)) {
        try stderr("Alias '{s}' does not exist.\n", .{name});
        process.exit(1);
    }
    try stderr("Deleted alias {s}\n", .{name});
}

pub fn cmdDefault(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len > 1) {
        try stderr("Usage: {s} default [version]\n", .{program_name});
        process.exit(1);
    }
    if (parsed.positionals.items.len == 0) {
        const target = try readAlias(allocator, config, "default") orelse {
            try stderr("No default version set.\n", .{});
            process.exit(1);
        };
        defer allocator.free(target);
        try stdout("{s}\n", .{target});
        return;
    }
    const target = parsed.positionals.items[0];
    try rejectUnsupportedSpec(target);
    try aliasTargetIsUsable(allocator, config, target);
    try setAlias(allocator, config, "default", target);
    try stderr("default -> {s}\n", .{target});
}

pub fn cmdCurrent(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    _ = args;
    if (try getCurrentVersionFromPath(allocator, config)) |ver| {
        defer allocator.free(ver);
        try stdout("{s}\n", .{ver});
        return;
    }
    if (try findSystemNode(allocator, config)) |node| {
        allocator.free(node);
        try stdout("system\n", .{});
        return;
    }
    try stdout("none\n", .{});
}

pub fn cmdWhich(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    const usage = try std.fmt.allocPrint(allocator, "Usage: {s} which [version]", .{program_name});
    defer allocator.free(usage);
    const spec = try requireSpec(allocator, &parsed, usage, parsed.silent);
    defer allocator.free(spec);
    const hit = try resolveLocalOrExit(allocator, config, spec, null);
    defer hit.deinit(allocator);
    switch (hit) {
        .system => {
            const node = try findSystemNode(allocator, config) orelse {
                try stderr("System version of node not found.\n", .{});
                process.exit(127);
            };
            defer allocator.free(node);
            try stdout("{s}\n", .{node});
        },
        .version => |ver| {
            const node = try fs.path.join(allocator, &.{ config.versions_dir, ver, "bin", "node" });
            defer allocator.free(node);
            fs.accessAbsolute(node, .{}) catch {
                try stderr("Version '{s}' is installed but bin/node is missing.\n", .{ver});
                process.exit(1);
            };
            try stdout("{s}\n", .{node});
        },
    }
}

pub fn cmdVersion(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len == 0 and parsed.lts == null) {
        try cmdCurrent(allocator, args, config);
        return;
    }
    if (parsed.positionals.items.len > 1) {
        try stderr("Usage: {s} version [version]\n", .{program_name});
        process.exit(1);
    }
    const spec = if (parsed.lts) |name| try ltsSpec(allocator, name) else try allocator.dupe(u8, parsed.positionals.items[0]);
    defer allocator.free(spec);
    const hit = resolveLocalSpec(allocator, config, spec, null, 0) catch |err| switch (err) {
        error.AliasCycle => {
            try stderr("The alias \"{s}\" leads to an infinite loop. Aborting.\n", .{spec});
            process.exit(8);
        },
        else => return err,
    };
    if (hit) |resolved| {
        defer resolved.deinit(allocator);
        switch (resolved) {
            .system => try stdout("system\n", .{}),
            .version => |ver| try stdout("{s}\n", .{ver}),
        }
        return;
    }
    try stdout("N/A\n", .{});
    process.exit(3);
}

pub fn cmdVersionRemote(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len > 1) {
        try stderr("Usage: {s} version-remote [version]\n", .{program_name});
        process.exit(1);
    }
    const raw = if (parsed.positionals.items.len == 1) parsed.positionals.items[0] else "";
    const query = version.parseVersionQuery(raw, parsed.lts);
    if (query.special == .current or query.special == .system or query.special == .default or (raw.len == 0 and parsed.lts == null)) {
        try stdout("N/A\n", .{});
        process.exit(3);
    }
    const resolved = try version.resolveRemoteQuery(allocator, query, config) orelse {
        try stdout("N/A\n", .{});
        process.exit(3);
    };
    defer allocator.free(resolved.version);
    defer allocator.free(resolved.filename);
    try stdout("{s}\n", .{resolved.version});
}

fn exitWith(term: process.Child.Term) noreturn {
    switch (term) {
        .Exited => |code| process.exit(code),
        else => process.exit(1),
    }
}

fn runInHit(allocator: mem.Allocator, config: ZnvmConfig, hit: LocalHit, argv: []const []const u8, silent: bool) !noreturn {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();
    const inherited = env_map.get("PATH") orelse "";
    const path_storage = switch (hit) {
        .system => try pathWithoutVersions(allocator, config, inherited),
        .version => |ver| try pathWithVersion(allocator, config, ver, inherited),
    };
    defer allocator.free(path_storage);
    try env_map.put("PATH", path_storage);

    switch (hit) {
        .system => {
            env_map.remove("ZNVM_CURRENT");
            env_map.remove("NVM_BIN");
            env_map.remove("NVM_INC");
            if (!silent) try stderr("Running system node\n", .{});
        },
        .version => |ver| {
            const node_bin = try fs.path.join(allocator, &.{ config.versions_dir, ver, "bin", "node" });
            defer allocator.free(node_bin);
            fs.accessAbsolute(node_bin, .{}) catch {
                try stderr("Version '{s}' is installed but bin/node is missing.\n", .{ver});
                process.exit(1);
            };
            const bin_path = try fs.path.join(allocator, &.{ config.versions_dir, ver, "bin" });
            defer allocator.free(bin_path);
            const inc_path = try fs.path.join(allocator, &.{ config.versions_dir, ver, "include", "node" });
            defer allocator.free(inc_path);
            try env_map.put("ZNVM_CURRENT", ver);
            try env_map.put("NPM_CONFIG_PREFIX", config.npm_prefix);
            try env_map.put("NVM_BIN", bin_path);
            try env_map.put("NVM_INC", inc_path);
            if (!silent) try stderr("Running node {s}\n", .{ver});
        },
    }

    var child = process.Child.init(argv, allocator);
    child.env_map = &env_map;
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    const term = try child.spawnAndWait();
    exitWith(term);
}

fn commandSpecAndArgs(allocator: mem.Allocator, config: ZnvmConfig, parsed: *const ParsedArgs, command_name: []const u8) !struct { spec: []u8, args: []const []const u8 } {
    const items = parsed.positionals.items;
    const first_is_version = parsed.lts == null and items.len > 0 and try isVersionSelector(allocator, config, items[0]);
    const spec = if (parsed.lts) |name|
        try ltsSpec(allocator, name)
    else if (first_is_version)
        try allocator.dupe(u8, items[0])
    else
        try readNvmrcSpec(allocator, parsed.silent) orelse {
            try stderr("Usage: {s} {s} [version] [args...]\nNo .nvmrc file found.\n", .{ program_name, command_name });
            process.exit(127);
        };
    const cmd_args = if (first_is_version) items[1..] else items;
    return .{ .spec = spec, .args = cmd_args };
}

pub fn cmdExec(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .command);
    defer parsed.deinit(allocator);
    const prepared = try commandSpecAndArgs(allocator, config, &parsed, "exec");
    defer allocator.free(prepared.spec);
    if (prepared.args.len == 0) {
        try stderr("Usage: {s} exec [version] <command> [args...]\n", .{program_name});
        process.exit(127);
    }
    try rejectUnsupportedSpec(prepared.spec);
    const hit = try resolveLocalOrExit(allocator, config, prepared.spec, null);
    defer hit.deinit(allocator);
    try runInHit(allocator, config, hit, prepared.args, parsed.silent);
}

pub fn cmdRun(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .command);
    defer parsed.deinit(allocator);
    const prepared = try commandSpecAndArgs(allocator, config, &parsed, "run");
    defer allocator.free(prepared.spec);
    try rejectUnsupportedSpec(prepared.spec);
    const hit = try resolveLocalOrExit(allocator, config, prepared.spec, null);
    defer hit.deinit(allocator);
    const node_bin = switch (hit) {
        .system => try findSystemNode(allocator, config) orelse {
            try stderr("System version of node not found.\n", .{});
            process.exit(127);
        },
        .version => |ver| try fs.path.join(allocator, &.{ config.versions_dir, ver, "bin", "node" }),
    };
    defer allocator.free(node_bin);

    var argv = std.ArrayList([]const u8){};
    defer argv.deinit(allocator);
    try argv.append(allocator, node_bin);
    try argv.appendSlice(allocator, prepared.args);
    try runInHit(allocator, config, hit, argv.items, parsed.silent);
}

pub fn cmdDeactivate(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len != 0) {
        try stderr("Usage: {s} deactivate\n", .{program_name});
        process.exit(1);
    }
    try emitDeactivate(allocator, config, parsed.silent, "Deactivated");
}
