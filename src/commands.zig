const platform = @import("platform.zig");
const std = @import("std");
const host = @import("host.zig");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const util = @import("util.zig");
const version = @import("version.zig");
const ZnvmConfig = @import("config.zig").ZnvmConfig;

const agent = @import("agent.zig");
const i18n = @import("i18n.zig");
const messages = @import("messages.zig");

const stdout = util.stdout;
const stderr = util.stderr;

fn failFmt(code: u8, comptime message: i18n.Msg, args: anytype) noreturn {
    var buf: [512]u8 = undefined;
    agent.fail(code, i18n.format(message, &buf, args));
}

fn na() !noreturn {
    if (agent.json_mode) agent.fail(3, "N/A");
    try stdout("N/A\n", .{});
    process.exit(3);
}

extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;
extern "c" fn _putenv_s(name: [*:0]const u8, value: [*:0]const u8) c_int;
extern "c" fn unsetenv(name: [*:0]const u8) c_int;

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
    reinstall_from: ?[]const u8 = null,
    latest_npm: bool = false,
    offline: bool = false,
    save: bool = false,
    skip_default_packages: bool = false,
    positionals: std.ArrayList([]const u8) = .empty,

    fn deinit(self: *ParsedArgs, allocator: mem.Allocator) void {
        self.positionals.deinit(allocator);
    }
};

const FlagMode = enum { strict, command };

fn shellQuote(allocator: mem.Allocator, value: []const u8) ![]u8 {
    var quoted: std.ArrayList(u8) = .empty;
    errdefer quoted.deinit(allocator);

    try quoted.append(allocator, '\'');
    for (value) |char| {
        if (char == '\'') {
            try quoted.appendSlice(allocator, if (platform.windows) "''" else "'\\''");
        } else {
            try quoted.append(allocator, char);
        }
    }
    try quoted.append(allocator, '\'');
    return quoted.toOwnedSlice(allocator);
}

fn underManagedPrefix(entry: []const u8, root: []const u8) bool {
    if (root.len == 0 or entry.len <= root.len) return false;
    if (!platform.pathPrefix(entry, root) or !platform.isSep(entry[root.len])) return false;
    const rest = entry[root.len + 1 ..];
    if (platform.pathPrefix(rest, "versions/")) return true;
    return rest.len > 2 and rest[0] == 'v' and mem.indexOf(u8, rest, "/bin") != null;
}

/// `realpath` rewrites symlink prefixes. macOS `/var` and `/tmp` are `/private/var`
/// and `/private/tmp`, so a node path and `NVM_DIR` can disagree until both are resolved.
fn pathEntryIsManaged(allocator: mem.Allocator, config: ZnvmConfig, entry: []const u8) !bool {
    for (config.managed_roots) |root| {
        if (underManagedPrefix(entry, root)) return true;
        const real_root = host.realpathAlloc(allocator, root) catch continue;
        defer allocator.free(real_root);
        if (underManagedPrefix(entry, real_root)) return true;
        const real_entry = host.realpathAlloc(allocator, entry) catch continue;
        defer allocator.free(real_entry);
        if (underManagedPrefix(real_entry, real_root)) return true;
    }
    return false;
}

fn managedVersionFromRealPath(allocator: mem.Allocator, config: ZnvmConfig, real_path: []const u8) !?[]u8 {
    if (!try pathEntryIsManaged(allocator, config, real_path)) return null;
    if (platform.windows) {
        const parent = fs.path.dirname(real_path) orelse return null;
        const name = fs.path.basename(parent);
        if (name.len < 2 or name[0] != 'v') return null;
        _ = std.SemanticVersion.parse(name[1..]) catch return null;
        return try allocator.dupe(u8, name);
    }
    const bin_at = mem.lastIndexOf(u8, real_path, "/bin/") orelse return null;
    const before = real_path[0..bin_at];
    const slash = mem.lastIndexOfScalar(u8, before, '/') orelse return null;
    const name = before[slash + 1 ..];
    if (name.len < 2 or name[0] != 'v') return null;
    return try allocator.dupe(u8, name);
}

fn withVPrefix(allocator: mem.Allocator, ver: []const u8) ![]u8 {
    if (ver.len > 0 and ver[0] == 'v') return allocator.dupe(u8, ver);
    return std.fmt.allocPrint(allocator, "v{s}", .{ver});
}

fn newVersionDir(allocator: mem.Allocator, config: ZnvmConfig, ver: []const u8) ![]u8 {
    const name = try withVPrefix(allocator, ver);
    defer allocator.free(name);
    if (version.isOldNodeLayout(name)) return fs.path.join(allocator, &.{ config.root_dir, name });
    return fs.path.join(allocator, &.{ config.versions_dir, name });
}

fn nodeBinaryIn(allocator: mem.Allocator, dir_path: []const u8) !?[]u8 {
    const node = try platform.nodePath(allocator, dir_path);
    if (std.Io.Dir.accessAbsolute(host.io(), node, .{})) {
        return node;
    } else |_| {
        allocator.free(node);
        return null;
    }
}

/// Directory of an installed version. nvm's `versions/node/vX` is preferred.
/// Older znvm trees (`versions/vX`) and Node < 0.12 (`$NVM_DIR/vX`) are still found.
fn locateVersionDir(allocator: mem.Allocator, config: ZnvmConfig, ver: []const u8) !?[]u8 {
    const preferred = try newVersionDir(allocator, config, ver);
    if (try nodeBinaryIn(allocator, preferred)) |node| {
        allocator.free(node);
        return preferred;
    }
    allocator.free(preferred);

    const name = try withVPrefix(allocator, ver);
    defer allocator.free(name);
    for (config.scan_dirs) |dir_path| {
        const candidate = try fs.path.join(allocator, &.{ dir_path, name });
        if (try nodeBinaryIn(allocator, candidate)) |node| {
            allocator.free(node);
            return candidate;
        }
        allocator.free(candidate);
    }
    return null;
}

fn versionHome(allocator: mem.Allocator, config: ZnvmConfig, ver: []const u8) ![]u8 {
    if (try locateVersionDir(allocator, config, ver)) |dir_path| return dir_path;
    return newVersionDir(allocator, config, ver);
}

fn pathEntries(allocator: mem.Allocator) !?[]const u8 {
    var env_map = try host.envMap(allocator);
    defer env_map.deinit();
    const path_env = env_map.get("PATH") orelse return null;
    return try allocator.dupe(u8, path_env);
}

pub fn activeVersion(allocator: mem.Allocator, config: ZnvmConfig) !?[]u8 {
    return getCurrentVersionFromPath(allocator, config);
}

fn getCurrentVersionFromPath(allocator: mem.Allocator, config: ZnvmConfig) !?[]u8 {
    const path_env_owned = try pathEntries(allocator) orelse return null;
    defer allocator.free(path_env_owned);

    var it = mem.splitScalar(u8, path_env_owned, platform.path_delimiter);
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        const node_path = try fs.path.join(allocator, &.{ dir, platform.node_name });
        defer allocator.free(node_path);
        std.Io.Dir.accessAbsolute(host.io(), node_path, .{}) catch continue;
        const real_path = host.realpathAlloc(allocator, node_path) catch continue;
        defer allocator.free(real_path);
        if (try managedVersionFromRealPath(allocator, config, real_path)) |ver| return ver;
    }
    return null;
}

fn findSystemNode(allocator: mem.Allocator, config: ZnvmConfig) !?[]u8 {
    const path_env_owned = try pathEntries(allocator) orelse return null;
    defer allocator.free(path_env_owned);

    var it = mem.splitScalar(u8, path_env_owned, platform.path_delimiter);
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        const node_path = try fs.path.join(allocator, &.{ dir, platform.node_name });
        defer allocator.free(node_path);
        std.Io.Dir.accessAbsolute(host.io(), node_path, .{}) catch continue;
        const real_path = host.realpathAlloc(allocator, node_path) catch continue;
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
    const home = try versionHome(allocator, config, ver);
    defer allocator.free(home);
    const bin_path = try platform.binDir(allocator, home);
    defer allocator.free(bin_path);
    const npm_bin_path = if (config.npm_prefix) |prefix| try platform.binDir(allocator, prefix) else null;
    defer if (npm_bin_path) |path| allocator.free(path);

    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    if (npm_bin_path) |path| {
        try list.appendSlice(allocator, path);
        try list.append(allocator, platform.path_delimiter);
    }
    try list.appendSlice(allocator, bin_path);

    var it = mem.splitScalar(u8, current_path, platform.path_delimiter);
    while (it.next()) |entry| {
        if (entry.len == 0 or try pathEntryIsManaged(allocator, config, entry) or mem.eql(u8, entry, bin_path)) continue;
        if (npm_bin_path) |path| if (mem.eql(u8, entry, path)) continue;
        try list.append(allocator, platform.path_delimiter);
        try list.appendSlice(allocator, entry);
    }
    return list.toOwnedSlice(allocator);
}

fn pathWithoutVersions(allocator: mem.Allocator, config: ZnvmConfig, current_path: []const u8) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    var it = mem.splitScalar(u8, current_path, platform.path_delimiter);
    while (it.next()) |entry| {
        if (entry.len == 0 or try pathEntryIsManaged(allocator, config, entry)) continue;
        if (list.items.len > 0) try list.append(allocator, platform.path_delimiter);
        try list.appendSlice(allocator, entry);
    }
    return list.toOwnedSlice(allocator);
}

fn currentPath(allocator: mem.Allocator) ![]u8 {
    var env_map = try host.envMap(allocator);
    defer env_map.deinit();
    return allocator.dupe(u8, env_map.get("PATH") orelse "");
}

fn emitExports(allocator: mem.Allocator, config: ZnvmConfig, ver: []const u8, silent: bool) !void {
    const home = try versionHome(allocator, config, ver);
    defer allocator.free(home);
    const node_bin = try platform.nodePath(allocator, home);
    defer allocator.free(node_bin);
    std.Io.Dir.accessAbsolute(host.io(), node_bin, .{}) catch {
        try i18n.err(messages.bin_missing, .{ver});
        process.exit(1);
    };

    const path = try currentPath(allocator);
    defer allocator.free(path);
    const new_path = try pathWithVersion(allocator, config, ver, path);
    defer allocator.free(new_path);
    const bin_path = try platform.binDir(allocator, home);
    defer allocator.free(bin_path);
    const inc_path = try fs.path.join(allocator, &.{ home, "include", "node" });
    defer allocator.free(inc_path);

    const quoted_path = try shellQuote(allocator, new_path);
    defer allocator.free(quoted_path);
    const quoted_version = try shellQuote(allocator, ver);
    defer allocator.free(quoted_version);
    const quoted_bin = try shellQuote(allocator, bin_path);
    defer allocator.free(quoted_bin);
    const quoted_inc = try shellQuote(allocator, inc_path);
    defer allocator.free(quoted_inc);

    putEnv(allocator, "PATH", new_path);
    putEnv(allocator, "ZNVM_CURRENT", ver);
    putEnv(allocator, "NVM_BIN", bin_path);
    putEnv(allocator, "NVM_INC", inc_path);
    try stdout(if (platform.windows) "$env:PATH={s}\n" else "export PATH={s}\n", .{quoted_path});
    try stdout(if (platform.windows) "$env:ZNVM_CURRENT={s}\n" else "export ZNVM_CURRENT={s}\n", .{quoted_version});
    if (config.npm_prefix) |prefix| {
        const quoted_prefix = try shellQuote(allocator, prefix);
        defer allocator.free(quoted_prefix);
        putEnv(allocator, "NPM_CONFIG_PREFIX", prefix);
        try stdout(if (platform.windows) "$env:NPM_CONFIG_PREFIX={s}\n" else "export NPM_CONFIG_PREFIX={s}\n", .{quoted_prefix});
    } else {
        clearEnv("NPM_CONFIG_PREFIX");
        try stdout(if (platform.windows) "Remove-Item Env:NPM_CONFIG_PREFIX -ErrorAction SilentlyContinue\n" else "unset NPM_CONFIG_PREFIX\n", .{});
    }
    try stdout(if (platform.windows) "$env:NVM_BIN={s}\n" else "export NVM_BIN={s}\n", .{quoted_bin});
    try stdout(if (platform.windows) "$env:NVM_INC={s}\n" else "export NVM_INC={s}\n", .{quoted_inc});
    if (!platform.windows) try stdout("hash -r 2>/dev/null || true\n", .{});
    if (!silent) try printUsing(allocator, config, ver);
}

fn printUsing(allocator: mem.Allocator, config: ZnvmConfig, ver: []const u8) !void {
    const bundled_npm = @import("bundled_npm.zig");
    const home = try versionHome(allocator, config, ver);
    defer allocator.free(home);
    const npm_ver = try bundled_npm.readVersion(allocator, home);
    defer if (npm_ver) |value| allocator.free(value);
    if (npm_ver) |npm| {
        try i18n.err(messages.using_with_npm, .{ ver, npm });
    } else {
        try i18n.err(messages.using_node_only, .{ver});
    }
}

fn emitDeactivate(allocator: mem.Allocator, config: ZnvmConfig, silent: bool, message: []const u8) !void {
    const path = try currentPath(allocator);
    defer allocator.free(path);
    const new_path = try pathWithoutVersions(allocator, config, path);
    defer allocator.free(new_path);
    const quoted_path = try shellQuote(allocator, new_path);
    defer allocator.free(quoted_path);

    putEnv(allocator, "PATH", new_path);
    clearEnv("ZNVM_CURRENT");
    clearEnv("NVM_BIN");
    clearEnv("NVM_INC");
    try stdout(if (platform.windows) "$env:PATH={s}\n" else "export PATH={s}\n", .{quoted_path});
    try stdout(if (platform.windows) "Remove-Item Env:ZNVM_CURRENT -ErrorAction SilentlyContinue\n" else "unset ZNVM_CURRENT\n", .{});
    try stdout(if (platform.windows) "Remove-Item Env:NVM_BIN -ErrorAction SilentlyContinue\n" else "unset NVM_BIN\n", .{});
    try stdout(if (platform.windows) "Remove-Item Env:NVM_INC -ErrorAction SilentlyContinue\n" else "unset NVM_INC\n", .{});
    if (!platform.windows) try stdout("hash -r 2>/dev/null || true\n", .{});
    if (!silent and message.len > 0) try stderr("{s}\n", .{message});
}

fn putEnv(allocator: mem.Allocator, key: [:0]const u8, value: []const u8) void {
    const owned = allocator.dupeSentinel(u8, value, 0) catch return;
    defer allocator.free(owned);
    if (platform.windows) {
        _ = _putenv_s(key, owned.ptr);
    } else {
        _ = setenv(key, owned.ptr, 1);
    }
}

fn clearEnv(key: [:0]const u8) void {
    if (platform.windows) {
        _ = _putenv_s(key, "");
    } else {
        _ = unsetenv(key);
    }
}

fn ensureDir(path: []const u8) !void {
    std.Io.Dir.createDirAbsolute(host.io(), path, .default_dir) catch |err| {
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
    const file = std.Io.Dir.openFileAbsolute(host.io(), path, .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    defer file.close(host.io());
    const content = try host.readToEndAlloc(file, allocator, 8192);
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
        try i18n.err(messages.alias_name_invalid, .{name});
        process.exit(1);
    }
    if (target.len == 0 or mem.indexOfScalar(u8, target, '\n') != null) {
        try i18n.err(messages.alias_target_invalid, .{});
        process.exit(1);
    }
    try ensureDir(config.root_dir);
    const alias_dir = try fs.path.join(allocator, &.{ config.root_dir, "alias" });
    defer allocator.free(alias_dir);
    try ensureDir(alias_dir);

    const path = try aliasFilePath(allocator, config, name);
    defer allocator.free(path);
    {
        const file = try std.Io.Dir.createFileAbsolute(host.io(), path, .{});
        defer file.close(host.io());
        try host.writeAll(file, target);
    }

    if (mem.eql(u8, name, "default")) {
        const legacy = try fs.path.join(allocator, &.{ config.root_dir, "default" });
        defer allocator.free(legacy);
        const file = try std.Io.Dir.createFileAbsolute(host.io(), legacy, .{});
        defer file.close(host.io());
        try host.writeAll(file, target);
    }
}

fn deleteAlias(allocator: mem.Allocator, config: ZnvmConfig, name: []const u8) !bool {
    if (!validAliasName(name)) return false;
    var removed = false;
    const path = try aliasFilePath(allocator, config, name);
    defer allocator.free(path);
    if (std.Io.Dir.deleteFileAbsolute(host.io(), path)) {
        removed = true;
    } else |err| {
        if (err != error.FileNotFound) return err;
    }
    if (mem.eql(u8, name, "default")) {
        const legacy = try fs.path.join(allocator, &.{ config.root_dir, "default" });
        defer allocator.free(legacy);
        if (std.Io.Dir.deleteFileAbsolute(host.io(), legacy)) {
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
    var list: std.ArrayList(AliasRecord) = .empty;
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

    if (std.Io.Dir.openDirAbsolute(host.io(), alias_dir, .{ .iterate = true })) |dir_open| {
        var dir = dir_open;
        defer dir.close(host.io());
        var it = dir.iterate();
        while (try it.next(host.io())) |entry| {
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
        try i18n.err(messages.no_iojs, .{program_name});
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
        error.AliasCycle => failFmt(8, messages.alias_cycle, .{spec}),
        else => return err,
    };
    return hit orelse failFmt(1, messages.not_installed_run, .{ spec, program_name, spec });
}

fn findUp(allocator: mem.Allocator, filename: []const u8) !?[]u8 {
    var dir = try host.cwdPath(allocator);
    while (true) {
        const candidate = try fs.path.join(allocator, &.{ dir, filename });
        if (std.Io.Dir.accessAbsolute(host.io(), candidate, .{})) {
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
        const parent = try allocator.dupeSentinel(u8, parent_slice, 0);
        allocator.free(dir);
        dir = parent;
    }
}

fn readVersionFile(allocator: mem.Allocator, path: []const u8, silent: bool) !?[]u8 {
    const content = try readSmallFile(allocator, path) orelse {
        try i18n.err(messages.invalid_version_file, .{path});
        process.exit(1);
    };
    defer allocator.free(content);
    const spec = version.parseNvmrc(content) orelse {
        try i18n.err(messages.invalid_version_file, .{path});
        process.exit(1);
    };
    if (!silent) try i18n.err(messages.found_version, .{ path, spec });
    return try allocator.dupe(u8, spec);
}

fn readNvmrcSpec(allocator: mem.Allocator, silent: bool) !?[]u8 {
    if (try findUp(allocator, ".nvmrc")) |path| {
        defer allocator.free(path);
        return readVersionFile(allocator, path, silent);
    }
    // nvm 0.40 only reads .nvmrc. .node-version is the other file projects
    // actually ship, so use it when no .nvmrc exists.
    if (try findUp(allocator, ".node-version")) |path| {
        defer allocator.free(path);
        return readVersionFile(allocator, path, silent);
    }
    return null;
}

fn writeCwdNvmrc(allocator: mem.Allocator, ver: []const u8, silent: bool) !void {
    const cwd = try host.cwdPath(allocator);
    defer allocator.free(cwd);
    const path = try fs.path.join(allocator, &.{ cwd, ".nvmrc" });
    defer allocator.free(path);
    const file = try std.Io.Dir.createFileAbsolute(host.io(), path, .{});
    defer file.close(host.io());
    try host.writeAll(file, ver);
    try host.writeAll(file, "\n");
    if (!silent) try i18n.err(messages.wrote_nvmrc, .{ver});
}

fn consumeFlag(parsed: *ParsedArgs, arg: []const u8) !bool {
    if (mem.eql(u8, arg, "--json") or mem.eql(u8, arg, "--yes") or mem.eql(u8, arg, "--llm")) return true;
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
        if (name.len == 0) failFmt(55, messages.lts_needs_name, .{});
        parsed.lts = name;
        return true;
    }
    if (mem.eql(u8, arg, "--default")) {
        parsed.set_default = true;
        return true;
    }
    if (mem.startsWith(u8, arg, "--alias=")) {
        const name = arg["--alias=".len..];
        if (name.len == 0) failFmt(55, messages.alias_needs_name, .{});
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
    if (mem.eql(u8, arg, "-s")) {
        try i18n.err(messages.no_source_build, .{program_name});
        process.exit(1);
    }
    if (mem.eql(u8, arg, "-b") or mem.eql(u8, arg, "--no-progress")) return true;
    if (mem.eql(u8, arg, "--latest-npm")) {
        parsed.latest_npm = true;
        return true;
    }
    if (mem.eql(u8, arg, "--offline")) {
        parsed.offline = true;
        return true;
    }
    if (mem.eql(u8, arg, "--save")) {
        parsed.save = true;
        return true;
    }
    if (mem.eql(u8, arg, "--skip-default-packages")) {
        parsed.skip_default_packages = true;
        return true;
    }
    const reinstall_flag: ?[]const u8 = if (mem.startsWith(u8, arg, "--reinstall-packages-from="))
        "--reinstall-packages-from="
    else if (mem.startsWith(u8, arg, "--copy-packages-from="))
        "--copy-packages-from="
    else
        null;
    if (reinstall_flag) |prefix| {
        const name = arg[prefix.len..];
        if (name.len == 0) failFmt(55, messages.option_needs_version, .{prefix});
        parsed.reinstall_from = name;
        return true;
    }
    if (mem.eql(u8, arg, "--reinstall-packages-from") or mem.eql(u8, arg, "--copy-packages-from")) {
        failFmt(55, messages.option_needs_eq_version, .{arg});
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
        if (mem.startsWith(u8, arg, "-") and (mode == .strict or parsed.positionals.items.len == 0)) {
            if (try consumeFlag(&parsed, arg)) continue;
            if (mode == .command) {
                while (index < args.len) : (index += 1) try parsed.positionals.append(allocator, args[index]);
                break;
            }
            failFmt(55, messages.unsupported_option, .{arg});
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

pub fn printHelp() !void {
    const help = @import("help.zig");
    try help.printNvm(program_name);
}

pub fn cmdHelp(args: []const []const u8) !void {
    const help = @import("help.zig");
    if (args.len <= 2) {
        try help.printNvm(program_name);
        return;
    }
    if (args.len == 3 and try help.printCommand(program_name, args[2])) return;
    if (args.len >= 3) try help.unknownCommand(args[2]);
    try help.printNvm(program_name);
    process.exit(1);
}

pub fn printNrmHelp() !void {
    const help = @import("help.zig");
    try help.printNrm();
}

pub fn cmdNrm(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    const reg = @import("registry.zig");
    if (args.len < 2) {
        try printNrmHelp();
        return;
    }
    const sub = args[1];
    const failed = blk: {
        if (mem.eql(u8, sub, "lang") and args.len == 2) {
            try stdout("{s}\n", .{@import("i18n.zig").code()});
            return;
        } else if ((mem.eql(u8, sub, "help") or mem.eql(u8, sub, "--help") or mem.eql(u8, sub, "-h")) and args.len == 2) {
            try printNrmHelp();
            return;
        } else if ((mem.eql(u8, sub, "ls") or mem.eql(u8, sub, "list")) and args.len == 2) {
            break :blk reg.listNames(allocator, config.root_dir);
        } else if (mem.eql(u8, sub, "use") and args.len == 3 and mem.eql(u8, args[2], "auto")) {
            break :blk reg.useAuto(allocator, config.root_dir);
        } else if (mem.eql(u8, sub, "use") and args.len == 3) {
            break :blk reg.useName(allocator, config.root_dir, args[2]);
        } else if (mem.eql(u8, sub, "current") and args.len == 2) {
            break :blk reg.current(allocator, config.root_dir, false);
        } else if (mem.eql(u8, sub, "current") and args.len == 3 and (mem.eql(u8, args[2], "-u") or mem.eql(u8, args[2], "--show-url"))) {
            break :blk reg.current(allocator, config.root_dir, true);
        } else if (mem.eql(u8, sub, "add") and (args.len == 4 or args.len == 5)) {
            break :blk reg.addName(allocator, config.root_dir, args[2], args[3]);
        } else if ((mem.eql(u8, sub, "del") or mem.eql(u8, sub, "rm")) and args.len == 3) {
            break :blk reg.delName(allocator, config.root_dir, args[2]);
        } else if (mem.eql(u8, sub, "test") and args.len == 2) {
            break :blk reg.testRegistries(allocator, config.root_dir, null);
        } else if (mem.eql(u8, sub, "test") and args.len == 3) {
            break :blk reg.testRegistries(allocator, config.root_dir, args[2]);
        } else if (mem.eql(u8, sub, "scope") and args.len >= 3 and (mem.eql(u8, args[2], "ls") or mem.eql(u8, args[2], "list")) and args.len == 3) {
            break :blk reg.listScopes(allocator, config.root_dir);
        } else if (mem.eql(u8, sub, "scope") and args.len == 5 and mem.eql(u8, args[2], "add")) {
            break :blk reg.add(allocator, config.root_dir, args[3], args[4]);
        } else if (mem.eql(u8, sub, "scope") and args.len == 4 and (mem.eql(u8, args[2], "del") or mem.eql(u8, args[2], "rm"))) {
            break :blk reg.removeScope(allocator, config.root_dir, args[3]);
        } else {
            try printNrmHelp();
            process.exit(1);
        }
    };
    failed catch |err| {
        try reg.printError(err);
        process.exit(1);
    };
}

pub fn cmdRegistry(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    const reg = @import("registry.zig");
    const sub = if (args.len < 3) "show" else args[2];
    const failed = blk: {
        if (mem.eql(u8, sub, "show") and args.len <= 3) {
            break :blk reg.show(allocator, config.root_dir);
        } else if (mem.eql(u8, sub, "set-default") and args.len == 4) {
            break :blk reg.setDefault(allocator, config.root_dir, args[3]);
        } else if (mem.eql(u8, sub, "add") and args.len == 5) {
            break :blk reg.add(allocator, config.root_dir, args[3], args[4]);
        } else if ((mem.eql(u8, sub, "remove") or mem.eql(u8, sub, "rm")) and args.len == 4) {
            break :blk reg.removeScope(allocator, config.root_dir, args[3]);
        } else if (mem.eql(u8, sub, "china") and args.len == 3) {
            break :blk reg.useChina(allocator, config.root_dir);
        } else if (mem.eql(u8, sub, "official") and args.len == 3) {
            break :blk reg.useOfficial(allocator, config.root_dir);
        } else if (mem.eql(u8, sub, "sync") and args.len == 3) {
            break :blk reg.sync(allocator, config.root_dir);
        } else {
            const help = @import("help.zig");
            _ = try help.printCommand(program_name, "registry");
            process.exit(1);
        }
    };
    failed catch |err| {
        try reg.printError(err);
        process.exit(1);
    };
}

pub fn cmdMirror(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    const mirror = @import("binary.zig");
    mirror.cmd(allocator, config.root_dir, if (args.len < 2) args[0..0] else args[2..]) catch |err| {
        try mirror.printError(err);
        process.exit(1);
    };
}

pub fn cmdEnv(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    _ = args;
    if (platform.windows) return emitPowerShellEnv(allocator, config);
    const root_dir = try shellQuote(allocator, config.root_dir);
    defer allocator.free(root_dir);

    var optional: std.ArrayList(u8) = .empty;
    defer optional.deinit(allocator);
    if (config.npm_prefix) |prefix| {
        const npm_bin_path = try platform.binDir(allocator, prefix);
        defer allocator.free(npm_bin_path);
        const path = try currentPath(allocator);
        defer allocator.free(path);
        var path_list: std.ArrayList(u8) = .empty;
        defer path_list.deinit(allocator);
        try path_list.appendSlice(allocator, npm_bin_path);
        var path_it = mem.splitScalar(u8, path, platform.path_delimiter);
        while (path_it.next()) |entry| {
            if (entry.len == 0 or mem.eql(u8, entry, npm_bin_path)) continue;
            try path_list.append(allocator, platform.path_delimiter);
            try path_list.appendSlice(allocator, entry);
        }
        const quoted_prefix = try shellQuote(allocator, prefix);
        defer allocator.free(quoted_prefix);
        const quoted_path = try shellQuote(allocator, path_list.items);
        defer allocator.free(quoted_path);
        try optional.print(allocator, "export NPM_CONFIG_PREFIX={s}\nexport PATH={s}\n", .{ quoted_prefix, quoted_path });
    }
    const optional_text = optional.items;

    const nvm_exe_raw: []const u8 = if (std.process.executablePathAlloc(host.io(), allocator)) |path| path else |_| try allocator.dupe(u8, "nvm");
    defer allocator.free(nvm_exe_raw);
    const nvm_exe = try shellQuote(allocator, nvm_exe_raw);
    defer allocator.free(nvm_exe);

    const shell_script =
        \\# nvm
        \\export NVM_DIR={s}
        \\if [ -f "$NVM_DIR/binaries.env" ]; then
        \\  . "$NVM_DIR/binaries.env"
        \\fi
        \\{s}
        \\__nvm_exe={s}
        \\
        \\__nvm_apply() {{
        \\  local result
        \\  local exit_code
        \\  result="$("$__nvm_exe" "$@")"
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
        \\__nvm_guide() {{
        \\  local result
        \\  local exit_code
        \\  while true; do
        \\    result="$("$__nvm_exe" --guide-step)"
        \\    exit_code=$?
        \\    if [ "$exit_code" -eq 2 ]; then
        \\      return 0
        \\    fi
        \\    if [ "$exit_code" -ne 0 ]; then
        \\      if [ -n "$result" ]; then
        \\        printf '%s\\n' "$result" >&2
        \\      fi
        \\      return "$exit_code"
        \\    fi
        \\    if [ -n "$result" ]; then
        \\      eval "$result"
        \\    fi
        \\  done
        \\}}
        \\
        \\# nrm is not a shell function. The nrm symlink runs the binary directly.
        \\nvm() {{
        \\  case "${{1-}}" in
        \\    ""|guide|interactive)
        \\      __nvm_guide "$@"
        \\      ;;
        \\    use|install|uninstall|rm|deactivate)
        \\      __nvm_apply "$@"
        \\      ;;
        \\    unload)
        \\      unset -f nvm __nvm_apply __nvm_guide __nvm_autoload __nvm_on_chdir 2>/dev/null || true
        \\      unset __nvm_last_pwd
        \\      ;;
        \\    *)
        \\      "$__nvm_exe" "$@"
        \\      ;;
        \\  esac
        \\}}
        \\
        \\__nvm_autoload() {{
        \\  local result
        \\  if result="$("$__nvm_exe" use --silent 2>/dev/null)"; then
        \\    [ -n "$result" ] && eval "$result"
        \\  elif result="$("$__nvm_exe" use --silent default 2>/dev/null)"; then
        \\    [ -n "$result" ] && eval "$result"
        \\  fi
        \\}}
        \\
        \\__nvm_on_chdir() {{
        \\  if [ "${{PWD-}}" = "${{__nvm_last_pwd-}}" ]; then
        \\    return 0
        \\  fi
        \\  __nvm_last_pwd="${{PWD-}}"
        \\  __nvm_autoload
        \\}}
        \\
        \\if [ -n "${{ZSH_VERSION-}}" ]; then
        \\  autoload -U add-zsh-hook 2>/dev/null || true
        \\  add-zsh-hook chpwd __nvm_on_chdir 2>/dev/null || true
        \\elif [ -n "${{BASH_VERSION-}}" ]; then
        \\  case ";${{PROMPT_COMMAND-}};" in
        \\    *";__nvm_on_chdir;"*) ;;
        \\    *) PROMPT_COMMAND="__nvm_on_chdir${{PROMPT_COMMAND:+;$PROMPT_COMMAND}}" ;;
        \\  esac
        \\fi
        \\
        \\__nvm_autoload
        \\__nvm_last_pwd="${{PWD-}}"
        \\
    ;
    try stdout(shell_script, .{ root_dir, optional_text, nvm_exe });
}

fn requireSpec(allocator: mem.Allocator, parsed: *const ParsedArgs, comptime usage: i18n.Msg, silent: bool) ![]u8 {
    if (parsed.positionals.items.len > 1) failFmt(1, usage, .{program_name});
    if (parsed.lts) |name| return ltsSpec(allocator, name);
    if (parsed.positionals.items.len == 1) return allocator.dupe(u8, parsed.positionals.items[0]);
    const found = try readNvmrcSpec(allocator, silent);
    if (found) |spec| return spec;
    var use_buf: [256]u8 = undefined;
    const rendered = i18n.format(usage, &use_buf, .{program_name});
    var buf: [512]u8 = undefined;
    agent.fail(127, i18n.format(messages.no_version_file, &buf, .{rendered}));
}

pub fn cmdUse(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    const spec = try requireSpec(allocator, &parsed, messages.usage_use, parsed.silent);
    defer allocator.free(spec);
    try rejectUnsupportedSpec(spec);
    const hit = try resolveLocalOrExit(allocator, config, spec, null);
    defer hit.deinit(allocator);
    try applyHit(allocator, config, hit, parsed.silent, i18n.t(messages.using_system));
    if (parsed.save) {
        switch (hit) {
            .system => {
                try i18n.err(messages.system_nvmrc, .{});
                process.exit(1);
            },
            .version => |ver| try writeCwdNvmrc(allocator, ver, parsed.silent),
        }
    }
}

fn resolveInstallSpec(allocator: mem.Allocator, config: ZnvmConfig, spec: []const u8, lts_flag: ?[]const u8, depth: u8) !?version.ResolvedRemote {
    if (depth > 8) return error.AliasCycle;
    const query = version.parseVersionQuery(spec, lts_flag);
    switch (query.special) {
        .system => {
            try i18n.err(messages.system_install, .{program_name});
            process.exit(1);
        },
        .current => {
            const current = try getCurrentVersionFromPath(allocator, config) orelse {
                try i18n.err(messages.no_active, .{});
                process.exit(1);
            };
            defer allocator.free(current);
            return version.resolveRemoteQuery(allocator, version.parseVersionQuery(current, null), config);
        },
        .default => {
            const target = try readAlias(allocator, config, "default") orelse {
                try i18n.err(messages.no_default, .{});
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
            try i18n.err(messages.alias_cycle_nl, .{target});
            process.exit(8);
        },
        else => return err,
    };
    if (hit) |resolved| {
        resolved.deinit(allocator);
        return;
    }
    try i18n.err(messages.not_installed_run_nl, .{ target, program_name, target });
    process.exit(1);
}

fn ensureTree(allocator: mem.Allocator, path: []const u8) !void {
    _ = allocator;
    try std.Io.Dir.cwd().createDirPath(host.io(), path);
}

fn fileNonEmpty(path: []const u8) bool {
    const file = std.Io.Dir.openFileAbsolute(host.io(), path, .{}) catch return false;
    defer file.close(host.io());
    const stat = file.stat(host.io()) catch return false;
    return stat.size > 0;
}

fn readPackageName(allocator: mem.Allocator, path: []const u8) !?[]u8 {
    const content = try readSmallFile(allocator, path) orelse return null;
    defer allocator.free(content);
    const parsed = std.json.parseFromSlice(
        struct { name: []const u8 },
        allocator,
        content,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    ) catch return null;
    defer parsed.deinit();
    if (parsed.value.name.len == 0) return null;
    return try allocator.dupe(u8, parsed.value.name);
}

fn listGlobalPackages(allocator: mem.Allocator, version_dir: []const u8) ![][]u8 {
    var list: std.ArrayList([]u8) = .empty;
    errdefer {
        for (list.items) |item| allocator.free(item);
        list.deinit(allocator);
    }
    const modules = try fs.path.join(allocator, if (platform.windows) &.{ version_dir, "node_modules" } else &.{ version_dir, "lib", "node_modules" });
    defer allocator.free(modules);
    var dir = std.Io.Dir.openDirAbsolute(host.io(), modules, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) return list.toOwnedSlice(allocator);
        return err;
    };
    defer dir.close(host.io());
    var it = dir.iterate();
    while (try it.next(host.io())) |entry| {
        if (entry.kind != .directory) continue;
        if (mem.eql(u8, entry.name, "npm") or mem.eql(u8, entry.name, "corepack") or mem.eql(u8, entry.name, ".bin")) continue;
        if (entry.name.len == 0 or entry.name[0] == '.') continue;
        const pkg_json = try fs.path.join(allocator, &.{ modules, entry.name, "package.json" });
        defer allocator.free(pkg_json);
        const name = try readPackageName(allocator, pkg_json) orelse try allocator.dupe(u8, entry.name);
        try list.append(allocator, name);
    }
    return list.toOwnedSlice(allocator);
}

fn npmInstallGlobal(allocator: mem.Allocator, config: ZnvmConfig, ver: []const u8, packages: []const []const u8) !void {
    if (packages.len == 0) return;
    const home = try versionHome(allocator, config, ver);
    defer allocator.free(home);
    const npm = try fs.path.join(allocator, if (platform.windows) &.{ home, "node_modules", "npm", "bin", "npm-cli.js" } else &.{ home, "bin", "npm" });
    defer allocator.free(npm);
    std.Io.Dir.accessAbsolute(host.io(), npm, .{}) catch {
        try i18n.err(messages.npm_missing, .{ver});
        process.exit(1);
    };
    const bin_path = try platform.binDir(allocator, home);
    defer allocator.free(bin_path);

    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    const node = try platform.nodePath(allocator, home);
    defer allocator.free(node);
    if (platform.windows) try argv.append(allocator, node);
    try argv.append(allocator, npm);
    try argv.append(allocator, "install");
    try argv.append(allocator, "-g");
    for (packages) |pkg| try argv.append(allocator, pkg);

    var env_map = try host.envMap(allocator);
    defer env_map.deinit();
    const inherited = env_map.get("PATH") orelse "";
    const path_value = try std.fmt.allocPrint(allocator, "{s}{c}{s}", .{ bin_path, platform.path_delimiter, inherited });
    defer allocator.free(path_value);
    try env_map.put("PATH", path_value);
    if (config.npm_prefix) |prefix| {
        try env_map.put("NPM_CONFIG_PREFIX", prefix);
    } else {
        _ = env_map.swapRemove("NPM_CONFIG_PREFIX");
    }

    const term = try host.spawnWait(argv.items, &env_map, .inherit);
    const ok = switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!ok) {
        try i18n.err(messages.npm_install_failed, .{ver});
        process.exit(1);
    }
}

fn reinstallPackages(allocator: mem.Allocator, config: ZnvmConfig, source_spec: []const u8, dest_ver: []const u8) !void {
    const source_hit = try resolveLocalOrExit(allocator, config, source_spec, null);
    defer source_hit.deinit(allocator);
    const source_ver = switch (source_hit) {
        .system => {
            try i18n.err(messages.reinstall_system, .{});
            process.exit(1);
        },
        .version => |ver| ver,
    };
    if (mem.eql(u8, source_ver, dest_ver)) {
        try i18n.err(messages.reinstall_current, .{});
        process.exit(2);
    }
    const source_dir = try versionHome(allocator, config, source_ver);
    defer allocator.free(source_dir);
    const names = try listGlobalPackages(allocator, source_dir);
    defer {
        for (names) |name| allocator.free(name);
        allocator.free(names);
    }
    try i18n.err(messages.reinstalling, .{source_ver});
    if (names.len == 0) {
        try i18n.err(messages.no_global_packages, .{});
        return;
    }
    for (names) |name| try stderr("{s}\n", .{name});
    const view = try allocator.alloc([]const u8, names.len);
    defer allocator.free(view);
    for (names, 0..) |name, index| view[index] = name;
    try npmInstallGlobal(allocator, config, dest_ver, view);
}

fn installDefaultPackages(allocator: mem.Allocator, config: ZnvmConfig, ver: []const u8, silent: bool) !void {
    const path = try fs.path.join(allocator, &.{ config.root_dir, "default-packages" });
    defer allocator.free(path);
    const content = try readSmallFile(allocator, path) orelse return;
    defer allocator.free(content);

    var specs: std.ArrayList([]u8) = .empty;
    defer {
        for (specs.items) |item| allocator.free(item);
        specs.deinit(allocator);
    }
    var lines = mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw| {
        const line = mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        if (mem.indexOfScalar(u8, line, ' ') != null or mem.indexOfScalar(u8, line, '\t') != null) {
            try i18n.err(messages.one_package_per_line, .{path});
            process.exit(1);
        }
        try specs.append(allocator, try allocator.dupe(u8, line));
    }
    if (specs.items.len == 0) return;
    if (!silent) try i18n.err(messages.installing_default_packages, .{path});
    const view = try allocator.alloc([]const u8, specs.items.len);
    defer allocator.free(view);
    for (specs.items, 0..) |item, index| view[index] = item;
    try npmInstallGlobal(allocator, config, ver, view);
}

pub fn cmdInstall(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    const spec = try requireSpec(allocator, &parsed, messages.usage_install, parsed.silent);
    defer allocator.free(spec);
    try rejectUnsupportedSpec(spec);

    const resolved = resolveInstallSpec(allocator, config, spec, null, 0) catch |err| switch (err) {
        error.AliasCycle => {
            try i18n.err(messages.alias_cycle_nl, .{spec});
            process.exit(8);
        },
        else => return err,
    } orelse {
        try i18n.err(messages.could_not_resolve, .{spec});
        process.exit(1);
    };
    defer allocator.free(resolved.version);
    defer allocator.free(resolved.filename);
    const ver = resolved.version;

    if (parsed.reinstall_from) |source| {
        const source_dir = try locateVersionDir(allocator, config, source) orelse {
            try i18n.err(messages.reinstall_from_installed, .{});
            process.exit(1);
        };
        allocator.free(source_dir);
    }

    const install_path = try newVersionDir(allocator, config, ver);
    defer allocator.free(install_path);
    const existing = try locateVersionDir(allocator, config, ver);
    defer if (existing) |dir_path| allocator.free(dir_path);
    if (existing != null) {
        if (!parsed.silent) try i18n.err(messages.already_installed, .{ver});
    } else {
        if (!parsed.silent) try i18n.err(messages.installing, .{ ver, resolved.arch });
        const download_url = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ config.mirror, ver, resolved.filename });
        defer allocator.free(download_url);
        const tar_path = try fs.path.join(allocator, &.{ config.root_dir, ".cache", "bin", resolved.filename });
        defer allocator.free(tar_path);
        try ensureTree(allocator, fs.path.dirname(tar_path) orelse config.root_dir);
        if (!fileNonEmpty(tar_path)) {
            if (parsed.offline) {
                try i18n.err(messages.no_cached_tarball, .{ver});
                process.exit(1);
            }
            try version.downloadFile(allocator, download_url, tar_path);
        } else if (!parsed.silent) {
            try i18n.err(messages.using_cached, .{resolved.filename});
        }
        if (!parsed.silent) try i18n.err(messages.extracting, .{});
        try ensureTree(allocator, install_path);

        const argv = &[_][]const u8{ "tar", if (platform.windows) "-xf" else "-xzf", tar_path, "-C", install_path, "--strip-components=1" };
        const term = try host.spawnWait(argv, null, .ignore);
        const extracted = switch (term) {
            .exited => |code| code == 0,
            else => false,
        };
        if (!extracted) {
            try i18n.err(messages.extraction_failed, .{});
            host.deleteTreeAbsolute(install_path) catch {};
            process.exit(1);
        }
        try i18n.err(messages.installed, .{ver});
    }

    const existing_default = try readAlias(allocator, config, "default");
    defer if (existing_default) |value| allocator.free(value);
    if (parsed.set_default or existing_default == null) {
        try setAlias(allocator, config, "default", ver);
        if (!parsed.silent) try i18n.err(messages.default_arrow, .{ver});
    }
    if (parsed.alias_to) |name| {
        try setAlias(allocator, config, name, ver);
        if (!parsed.silent) try i18n.err(messages.alias_arrow, .{ name, ver });
    }
    if (parsed.reinstall_from) |source| try reinstallPackages(allocator, config, source, ver);
    if (parsed.latest_npm) try npmInstallGlobal(allocator, config, ver, &.{"npm@latest"});
    if (!parsed.skip_default_packages) try installDefaultPackages(allocator, config, ver, parsed.silent);
    if (parsed.save) try writeCwdNvmrc(allocator, ver, parsed.silent);

    try emitExports(allocator, config, ver, parsed.silent);
}

fn isActive(active: ?[]const u8, ver: []const u8) bool {
    const current = active orelse return false;
    return mem.eql(u8, current, ver);
}

fn writeListed(sink: *agent.Sink, ver: []const u8, current: bool) !void {
    try sink.beginObject();
    try sink.fieldString("version", ver);
    try sink.fieldBool("current", current);
    try sink.endObject();
}

fn listJson(allocator: mem.Allocator, config: ZnvmConfig, parsed: *const ParsedArgs, installed: []const []const u8, active: ?[]const u8) !void {
    const system_node = if (active == null) try findSystemNode(allocator, config) else null;
    defer if (system_node) |path| allocator.free(path);
    const system_active = system_node != null;

    var sink = agent.Sink.init(allocator);
    defer sink.deinit();
    try sink.beginObject();
    if (active) |ver| {
        try sink.fieldString("current", ver);
    } else if (system_active) {
        try sink.fieldString("current", "system");
    } else {
        try sink.fieldNull("current");
    }
    try sink.key("versions");
    try sink.beginArray();
    var shown: usize = 0;
    if (parsed.positionals.items.len == 1) {
        const pattern = parsed.positionals.items[0];
        const query = version.parseVersionQuery(pattern, parsed.lts);
        if (query.prefix.len > 0 and query.special == .none and query.lts == null) {
            for (installed) |ver| {
                if (ver.len < 2 or ver[0] != 'v') continue;
                if (!version.matchesVersionPrefix(ver[1..], query.prefix)) continue;
                try writeListed(&sink, ver, isActive(active, ver));
                shown += 1;
            }
        } else if (resolveLocalSpec(allocator, config, pattern, parsed.lts, 0) catch null) |hit| {
            defer hit.deinit(allocator);
            switch (hit) {
                .version => |ver| {
                    try writeListed(&sink, ver, isActive(active, ver));
                    shown += 1;
                },
                .system => {
                    try writeListed(&sink, "system", system_active);
                    shown += 1;
                },
            }
        }
    } else {
        for (installed) |ver| {
            try writeListed(&sink, ver, isActive(active, ver));
            shown += 1;
        }
    }
    try sink.endArray();
    try sink.key("aliases");
    try sink.beginArray();
    if (parsed.positionals.items.len == 0 and !parsed.no_alias) {
        const aliases = try loadAliases(allocator, config);
        defer freeAliases(allocator, aliases);
        for (aliases) |item| {
            try sink.beginObject();
            try sink.fieldString("name", item.name);
            try sink.fieldString("target", item.target);
            try sink.endObject();
        }
    }
    try sink.endArray();
    try sink.endObject();
    if (parsed.positionals.items.len == 1 and shown == 0) agent.fail(3, "N/A");
    try sink.flush();
}

pub fn cmdList(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len > 1) failFmt(1, messages.usage_ls, .{program_name});
    if (parsed.no_alias and parsed.positionals.items.len > 0) {
        failFmt(55, messages.no_alias_flag, .{});
    }

    const installed = try version.getInstalledVersions(allocator, config);
    defer freeInstalled(allocator, installed);
    const current = try getCurrentVersionFromPath(allocator, config);
    defer if (current) |value| allocator.free(value);
    if (agent.json_mode) return listJson(allocator, config, &parsed, installed, current);

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
        if (shown == 0) try na();
        return;
    }

    if (installed.len == 0) {
        try i18n.out(messages.no_versions, .{});
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
    if (parsed.positionals.items.len > 1) failFmt(1, messages.usage_ls_remote, .{program_name});
    const raw = if (parsed.positionals.items.len == 1) parsed.positionals.items[0] else "";
    var query = version.parseVersionQuery(raw, parsed.lts);
    if (query.special == .current or query.special == .system or query.special == .default) try na();
    if (query.special == .latest) query.special = .none;
    const list_all = query.special == .none and query.lts == null and query.prefix.len == 0;

    const index = version.loadRemoteIndex(allocator, config) catch |err| {
        failFmt(1, messages.fetch_index, .{@errorName(err)});
    };
    defer index.deinit();

    var matched: std.ArrayList(version.NodeEntry) = .empty;
    defer matched.deinit(allocator);
    for (index.value) |entry| {
        if (!version.isInstallable(entry, config.os, config.arch)) continue;
        if (!list_all and !version.entryMatchesQuery(entry, query)) continue;
        if (entry.version.len < 2 or entry.version[0] != 'v') continue;
        _ = std.SemanticVersion.parse(entry.version[1..]) catch continue;
        try matched.append(allocator, entry);
    }
    if (matched.items.len == 0) try na();
    const Sorter = struct {
        fn less(_: void, lhs: version.NodeEntry, rhs: version.NodeEntry) bool {
            const left = std.SemanticVersion.parse(lhs.version[1..]) catch return false;
            const right = std.SemanticVersion.parse(rhs.version[1..]) catch return true;
            return left.order(right) == .lt;
        }
    };
    mem.sort(version.NodeEntry, matched.items, {}, Sorter.less);
    if (agent.json_mode) {
        var sink = agent.Sink.init(allocator);
        defer sink.deinit();
        try sink.beginObject();
        try sink.key("versions");
        try sink.beginArray();
        for (matched.items) |entry| {
            try sink.beginObject();
            try sink.fieldString("version", entry.version);
            if (version.entryLtsName(entry)) |name| {
                try sink.fieldString("lts", name);
            } else {
                try sink.fieldNull("lts");
            }
            try sink.endObject();
        }
        try sink.endArray();
        try sink.endObject();
        try sink.flush();
        return;
    }
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
        try i18n.err(messages.usage_uninstall, .{program_name});
        process.exit(1);
    }
    const spec = if (parsed.lts) |name| try ltsSpec(allocator, name) else try allocator.dupe(u8, parsed.positionals.items[0]);
    defer allocator.free(spec);
    try rejectUnsupportedSpec(spec);
    const hit = try resolveLocalOrExit(allocator, config, spec, null);
    defer hit.deinit(allocator);
    switch (hit) {
        .system => {
            try i18n.err(messages.system_uninstall, .{program_name});
            process.exit(1);
        },
        .version => |ver| {
            const active = try getCurrentVersionFromPath(allocator, config);
            defer if (active) |value| allocator.free(value);
            const path = try locateVersionDir(allocator, config, ver) orelse {
                try i18n.err(messages.version_not_installed, .{ver});
                process.exit(1);
            };
            defer allocator.free(path);
            try host.deleteTreeAbsolute(path);
            try i18n.err(messages.uninstalled, .{ver});
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
        try i18n.err(messages.usage_alias, .{program_name});
        process.exit(1);
    }
    if (parsed.positionals.items.len == 2) {
        const name = parsed.positionals.items[0];
        const target = parsed.positionals.items[1];
        try rejectUnsupportedSpec(target);
        try aliasTargetIsUsable(allocator, config, target);
        try setAlias(allocator, config, name, target);
        try i18n.err(messages.alias_arrow, .{ name, target });
        return;
    }
    const pattern = if (parsed.positionals.items.len == 1) parsed.positionals.items[0] else null;
    if (!try printAliases(allocator, config, pattern)) {
        if (pattern) |_| {
            try i18n.err(messages.no_alias, .{});
            process.exit(1);
        }
    }
}

pub fn cmdUnalias(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len != 1) {
        try i18n.err(messages.usage_unalias, .{program_name});
        process.exit(1);
    }
    const name = parsed.positionals.items[0];
    if (!try deleteAlias(allocator, config, name)) {
        try i18n.err(messages.alias_missing, .{name});
        process.exit(1);
    }
    try i18n.err(messages.deleted_alias, .{name});
}

pub fn cmdDefault(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len > 1) {
        try i18n.err(messages.usage_default, .{program_name});
        process.exit(1);
    }
    if (parsed.positionals.items.len == 0) {
        const target = try readAlias(allocator, config, "default") orelse {
            try i18n.err(messages.no_default, .{});
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
    try i18n.err(messages.default_arrow, .{target});
}

fn emitVersionLabel(allocator: mem.Allocator, label: []const u8) !void {
    if (!agent.json_mode) {
        try stdout("{s}\n", .{label});
        return;
    }
    var sink = agent.Sink.init(allocator);
    defer sink.deinit();
    try sink.beginObject();
    try sink.fieldString("version", label);
    try sink.endObject();
    try sink.flush();
}

fn emitWhich(allocator: mem.Allocator, ver: []const u8, path: []const u8) !void {
    if (!agent.json_mode) {
        try stdout("{s}\n", .{path});
        return;
    }
    var sink = agent.Sink.init(allocator);
    defer sink.deinit();
    try sink.beginObject();
    try sink.fieldString("version", ver);
    try sink.fieldString("path", path);
    try sink.endObject();
    try sink.flush();
}

pub fn cmdCurrent(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    _ = args;
    if (try getCurrentVersionFromPath(allocator, config)) |ver| {
        defer allocator.free(ver);
        try emitVersionLabel(allocator, ver);
        return;
    }
    if (try findSystemNode(allocator, config)) |node| {
        allocator.free(node);
        try emitVersionLabel(allocator, "system");
        return;
    }
    try emitVersionLabel(allocator, "none");
}

pub fn cmdWhich(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    const spec = try requireSpec(allocator, &parsed, messages.usage_which, parsed.silent);
    defer allocator.free(spec);
    const hit = try resolveLocalOrExit(allocator, config, spec, null);
    defer hit.deinit(allocator);
    switch (hit) {
        .system => {
            const node = try findSystemNode(allocator, config) orelse failFmt(127, messages.system_node_missing, .{});
            defer allocator.free(node);
            try emitWhich(allocator, "system", node);
        },
        .version => |ver| {
            const home = try versionHome(allocator, config, ver);
            defer allocator.free(home);
            const node = try platform.nodePath(allocator, home);
            defer allocator.free(node);
            std.Io.Dir.accessAbsolute(host.io(), node, .{}) catch failFmt(1, messages.bin_missing_plain, .{ver});
            try emitWhich(allocator, ver, node);
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
    if (parsed.positionals.items.len > 1) failFmt(1, messages.usage_version, .{program_name});
    const spec = if (parsed.lts) |name| try ltsSpec(allocator, name) else try allocator.dupe(u8, parsed.positionals.items[0]);
    defer allocator.free(spec);
    const hit = resolveLocalSpec(allocator, config, spec, null, 0) catch |err| switch (err) {
        error.AliasCycle => failFmt(8, messages.alias_cycle, .{spec}),
        else => return err,
    };
    if (hit) |resolved| {
        defer resolved.deinit(allocator);
        switch (resolved) {
            .system => try emitVersionLabel(allocator, "system"),
            .version => |ver| try emitVersionLabel(allocator, ver),
        }
        return;
    }
    try na();
}

pub fn cmdVersionRemote(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len > 1) {
        try i18n.err(messages.usage_version_remote, .{program_name});
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
        .exited => |code| process.exit(code),
        else => process.exit(1),
    }
}

fn runInHit(allocator: mem.Allocator, config: ZnvmConfig, hit: LocalHit, argv: []const []const u8, silent: bool) !noreturn {
    var env_map = try host.envMap(allocator);
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
            _ = env_map.swapRemove("ZNVM_CURRENT");
            _ = env_map.swapRemove("NVM_BIN");
            _ = env_map.swapRemove("NVM_INC");
            if (!silent) try i18n.err(messages.running_system, .{});
        },
        .version => |ver| {
            const home = try versionHome(allocator, config, ver);
            defer allocator.free(home);
            const node_bin = try platform.nodePath(allocator, home);
            defer allocator.free(node_bin);
            std.Io.Dir.accessAbsolute(host.io(), node_bin, .{}) catch {
                try i18n.err(messages.bin_missing, .{ver});
                process.exit(1);
            };
            const bin_path = try platform.binDir(allocator, home);
            defer allocator.free(bin_path);
            const inc_path = try fs.path.join(allocator, &.{ home, "include", "node" });
            defer allocator.free(inc_path);
            try env_map.put("ZNVM_CURRENT", ver);
            if (config.npm_prefix) |prefix| {
                try env_map.put("NPM_CONFIG_PREFIX", prefix);
            } else {
                _ = env_map.swapRemove("NPM_CONFIG_PREFIX");
            }
            try env_map.put("NVM_BIN", bin_path);
            try env_map.put("NVM_INC", inc_path);
            if (!silent) try i18n.err(messages.running_node, .{ver});
        },
    }

    // Invoke bundled npm through Node instead of cmd.exe: preserves literal
    // arguments (including shell metacharacters) without a second shell parse.
    if (platform.windows and argv.len > 0 and (mem.eql(u8, argv[0], "npm") or mem.eql(u8, argv[0], "npx"))) {
        switch (hit) {
            .version => |ver| {
                const home = try versionHome(allocator, config, ver);
                defer allocator.free(home);
                const node = try platform.nodePath(allocator, home);
                defer allocator.free(node);
                const cli = try fs.path.join(allocator, &.{ home, "node_modules", "npm", "bin", if (mem.eql(u8, argv[0], "npm")) "npm-cli.js" else "npx-cli.js" });
                defer allocator.free(cli);
                var npm_args: std.ArrayList([]const u8) = .empty;
                defer npm_args.deinit(allocator);
                try npm_args.appendSlice(allocator, &.{ node, cli });
                try npm_args.appendSlice(allocator, argv[1..]);
                exitWith(try host.spawnWait(npm_args.items, &env_map, .inherit));
            },
            .system => {},
        }
    }
    const term = try host.spawnWait(argv, &env_map, .inherit);
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
            try i18n.err(messages.usage_run_missing, .{ program_name, command_name });
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
        try i18n.err(messages.usage_exec, .{program_name});
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
            try i18n.err(messages.system_node_missing_nl, .{});
            process.exit(127);
        },
        .version => |ver| blk: {
            const home = try versionHome(allocator, config, ver);
            defer allocator.free(home);
            break :blk try platform.nodePath(allocator, home);
        },
    };
    defer allocator.free(node_bin);

    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    try argv.append(allocator, node_bin);
    try argv.appendSlice(allocator, prepared.args);
    try runInHit(allocator, config, hit, argv.items, parsed.silent);
}

pub fn cmdReinstallPackages(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len != 1) {
        try i18n.err(messages.usage_reinstall, .{program_name});
        process.exit(127);
    }
    const current = try getCurrentVersionFromPath(allocator, config) orelse {
        try i18n.err(messages.no_active_use_first, .{program_name});
        process.exit(1);
    };
    defer allocator.free(current);
    try reinstallPackages(allocator, config, parsed.positionals.items[0], current);
}

pub fn cmdInstallLatestNpm(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len != 0) {
        try i18n.err(messages.usage_latest_npm, .{program_name});
        process.exit(127);
    }
    const current = try getCurrentVersionFromPath(allocator, config) orelse {
        try i18n.err(messages.no_active_use_first, .{program_name});
        process.exit(1);
    };
    defer allocator.free(current);
    try npmInstallGlobal(allocator, config, current, &.{"npm@latest"});
}

pub fn cmdCache(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    const action = if (args.len >= 2 and mem.eql(u8, args[1], "clear-cache"))
        "clear"
    else if (args.len >= 3)
        args[2]
    else
        "";
    if (action.len == 0) {
        try i18n.err(messages.usage_cache, .{program_name});
        process.exit(127);
    }
    const cache_dir = try fs.path.join(allocator, &.{ config.root_dir, ".cache" });
    defer allocator.free(cache_dir);
    if (mem.eql(u8, action, "dir")) {
        try stdout("{s}\n", .{cache_dir});
        return;
    }
    if (mem.eql(u8, action, "clear")) {
        host.deleteTreeAbsolute(cache_dir) catch {};
        try ensureDir(cache_dir);
        try i18n.out(messages.cache_cleared, .{program_name});
        return;
    }
    try i18n.err(messages.usage_cache, .{program_name});
    process.exit(127);
}

pub fn cmdDebug(allocator: mem.Allocator, config: ZnvmConfig) !void {
    const installed = try version.getInstalledVersions(allocator, config);
    defer freeInstalled(allocator, installed);
    try i18n.err(messages.debug_version, .{"v2.9.4"});
    try i18n.err(messages.debug_dir, .{config.root_dir});
    try i18n.err(messages.debug_versions, .{config.versions_dir});
    try i18n.err(messages.debug_mirror, .{config.mirror});
    try i18n.err(messages.debug_platform, .{ config.os, config.arch });
    try i18n.err(messages.debug_installed, .{installed.len});
    if (config.npm_prefix) |prefix| {
        try i18n.err(messages.debug_prefix, .{prefix});
    } else {
        try i18n.err(messages.debug_prefix_per_node, .{});
    }
}

pub fn cmdDeactivate(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len != 0) {
        try i18n.err(messages.usage_deactivate, .{program_name});
        process.exit(1);
    }
    try emitDeactivate(allocator, config, parsed.silent, i18n.t(messages.deactivated));
}

fn emitPowerShellEnv(allocator: mem.Allocator, config: ZnvmConfig) !void {
    const root = try shellQuote(allocator, config.root_dir);
    defer allocator.free(root);
    const exe = try std.process.executablePathAlloc(host.io(), allocator);
    defer allocator.free(exe);
    const quoted_exe = try shellQuote(allocator, exe);
    defer allocator.free(quoted_exe);
    try stdout("$env:NVM_DIR={s}\n$global:__znvm_exe={s}\n", .{ root, quoted_exe });
    if (config.npm_prefix) |prefix| {
        const quoted_prefix = try shellQuote(allocator, prefix);
        defer allocator.free(quoted_prefix);
        try stdout("$env:NPM_CONFIG_PREFIX={s}\n", .{quoted_prefix});
    }
    try stdout("{s}\n", .{@embedFile("../scripts/nvm.ps1")});
}
