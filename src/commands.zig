const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const util = @import("util.zig");
const version = @import("version.zig");
const ZnvmConfig = @import("config.zig").ZnvmConfig;

const agent = @import("agent.zig");

const stdout = util.stdout;
const stderr = util.stderr;

fn failFmt(code: u8, comptime fmt: []const u8, args: anytype) noreturn {
    var buf: [512]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, fmt, args) catch "error";
    agent.fail(code, message);
}

fn na() !noreturn {
    if (agent.json_mode) agent.fail(3, "N/A");
    try stdout("N/A\n", .{});
    process.exit(3);
}

extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;
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

fn underManagedPrefix(entry: []const u8, root: []const u8) bool {
    if (root.len == 0 or entry.len <= root.len) return false;
    if (!mem.startsWith(u8, entry, root) or entry[root.len] != '/') return false;
    const rest = entry[root.len + 1 ..];
    if (mem.startsWith(u8, rest, "versions/")) return true;
    return rest.len > 2 and rest[0] == 'v' and mem.indexOf(u8, rest, "/bin") != null;
}

/// `realpath` rewrites symlink prefixes. macOS `/var` and `/tmp` are `/private/var`
/// and `/private/tmp`, so a node path and `NVM_DIR` can disagree until both are resolved.
fn pathEntryIsManaged(allocator: mem.Allocator, config: ZnvmConfig, entry: []const u8) !bool {
    for (config.managed_roots) |root| {
        if (underManagedPrefix(entry, root)) return true;
        const real_root = fs.realpathAlloc(allocator, root) catch continue;
        defer allocator.free(real_root);
        if (underManagedPrefix(entry, real_root)) return true;
        const real_entry = fs.realpathAlloc(allocator, entry) catch continue;
        defer allocator.free(real_entry);
        if (underManagedPrefix(real_entry, real_root)) return true;
    }
    return false;
}

fn managedVersionFromRealPath(allocator: mem.Allocator, config: ZnvmConfig, real_path: []const u8) !?[]u8 {
    if (!try pathEntryIsManaged(allocator, config, real_path)) return null;
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
    const node = try fs.path.join(allocator, &.{ dir_path, "bin", "node" });
    if (fs.accessAbsolute(node, .{})) {
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
    var env_map = try process.getEnvMap(allocator);
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
    const home = try versionHome(allocator, config, ver);
    defer allocator.free(home);
    const bin_path = try fs.path.join(allocator, &.{ home, "bin" });
    defer allocator.free(bin_path);
    const npm_bin_path = if (config.npm_prefix) |prefix| try fs.path.join(allocator, &.{ prefix, "bin" }) else null;
    defer if (npm_bin_path) |path| allocator.free(path);

    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    if (npm_bin_path) |path| {
        try list.appendSlice(allocator, path);
        try list.append(allocator, ':');
    }
    try list.appendSlice(allocator, bin_path);

    var it = mem.splitScalar(u8, current_path, ':');
    while (it.next()) |entry| {
        if (entry.len == 0 or try pathEntryIsManaged(allocator, config, entry) or mem.eql(u8, entry, bin_path)) continue;
        if (npm_bin_path) |path| if (mem.eql(u8, entry, path)) continue;
        try list.append(allocator, ':');
        try list.appendSlice(allocator, entry);
    }
    return list.toOwnedSlice(allocator);
}

fn pathWithoutVersions(allocator: mem.Allocator, config: ZnvmConfig, current_path: []const u8) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    var it = mem.splitScalar(u8, current_path, ':');
    while (it.next()) |entry| {
        if (entry.len == 0 or try pathEntryIsManaged(allocator, config, entry)) continue;
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
    const home = try versionHome(allocator, config, ver);
    defer allocator.free(home);
    const node_bin = try fs.path.join(allocator, &.{ home, "bin", "node" });
    defer allocator.free(node_bin);
    fs.accessAbsolute(node_bin, .{}) catch {
        try stderr("Version '{s}' is installed but bin/node is missing.\n", .{ver});
        process.exit(1);
    };

    const path = try currentPath(allocator);
    defer allocator.free(path);
    const new_path = try pathWithVersion(allocator, config, ver, path);
    defer allocator.free(new_path);
    const bin_path = try fs.path.join(allocator, &.{ home, "bin" });
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
    try stdout("export PATH={s}\n", .{quoted_path});
    try stdout("export ZNVM_CURRENT={s}\n", .{quoted_version});
    if (config.npm_prefix) |prefix| {
        const quoted_prefix = try shellQuote(allocator, prefix);
        defer allocator.free(quoted_prefix);
        putEnv(allocator, "NPM_CONFIG_PREFIX", prefix);
        try stdout("export NPM_CONFIG_PREFIX={s}\n", .{quoted_prefix});
    } else {
        _ = unsetenv("NPM_CONFIG_PREFIX");
        try stdout("unset NPM_CONFIG_PREFIX\n", .{});
    }
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

    putEnv(allocator, "PATH", new_path);
    _ = unsetenv("ZNVM_CURRENT");
    _ = unsetenv("NVM_BIN");
    _ = unsetenv("NVM_INC");
    try stdout("export PATH={s}\n", .{quoted_path});
    try stdout("unset ZNVM_CURRENT\n", .{});
    try stdout("unset NVM_BIN\n", .{});
    try stdout("unset NVM_INC\n", .{});
    try stdout("hash -r 2>/dev/null || true\n", .{});
    if (!silent and message.len > 0) try stderr("{s}\n", .{message});
}

fn putEnv(allocator: mem.Allocator, key: [:0]const u8, value: []const u8) void {
    const owned = allocator.dupeZ(u8, value) catch return;
    defer allocator.free(owned);
    _ = setenv(key, owned.ptr, 1);
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
        error.AliasCycle => failFmt(8, "The alias \"{s}\" leads to an infinite loop. Aborting.", .{spec}),
        else => return err,
    };
    return hit orelse failFmt(1, "Version '{s}' is not installed. Run '{s} install {s}' first.", .{ spec, program_name, spec });
}

fn findUp(allocator: mem.Allocator, filename: []const u8) !?[]u8 {
    var dir = try fs.cwd().realpathAlloc(allocator, ".");
    while (true) {
        const candidate = try fs.path.join(allocator, &.{ dir, filename });
        if (fs.accessAbsolute(candidate, .{})) {
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

fn readVersionFile(allocator: mem.Allocator, path: []const u8, silent: bool) !?[]u8 {
    const content = try readSmallFile(allocator, path) orelse {
        try stderr("invalid version file: {s}\n", .{path});
        process.exit(1);
    };
    defer allocator.free(content);
    const spec = version.parseNvmrc(content) orelse {
        try stderr("invalid version file: {s}\n", .{path});
        process.exit(1);
    };
    if (!silent) try stderr("Found '{s}' with version <{s}>\n", .{ path, spec });
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
    const cwd = try fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);
    const path = try fs.path.join(allocator, &.{ cwd, ".nvmrc" });
    defer allocator.free(path);
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(ver);
    try file.writeAll("\n");
    if (!silent) try stderr("Wrote version number ({s}) to .nvmrc\n", .{ver});
}

fn consumeFlag(parsed: *ParsedArgs, arg: []const u8) !bool {
    if (mem.eql(u8, arg, "--json") or mem.eql(u8, arg, "--yes")) return true;
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
        if (name.len == 0) failFmt(55, "Option \"--lts=\" needs an LTS name.", .{});
        parsed.lts = name;
        return true;
    }
    if (mem.eql(u8, arg, "--default")) {
        parsed.set_default = true;
        return true;
    }
    if (mem.startsWith(u8, arg, "--alias=")) {
        const name = arg["--alias=".len..];
        if (name.len == 0) failFmt(55, "Option \"--alias=\" needs a name.", .{});
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
        try stderr("{s} installs official Node.js binaries and does not compile from source (-s).\n", .{program_name});
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
        if (name.len == 0) failFmt(55, "Option \"{s}\" needs a version.", .{prefix});
        parsed.reinstall_from = name;
        return true;
    }
    if (mem.eql(u8, arg, "--reinstall-packages-from") or mem.eql(u8, arg, "--copy-packages-from")) {
        failFmt(55, "Option \"{s}\" needs =version.", .{arg});
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
            failFmt(55, "Unsupported option \"{s}\".", .{arg});
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
    try stdout(
        \\{s} - fast Node.js version manager
        \\
        \\Version selectors: 20, 20.11, v20.11.0, node, stable, lts/*, lts/<name>, default, current, system
        \\.nvmrc is read from the current directory and its parents. .node-version is used when no .nvmrc exists.
        \\'#' comments are ignored.
        \\
        \\Commands:
        \\  install [version] [--lts] [--lts=<name>] [--default] [--alias=<name>] [--save]
        \\          [--reinstall-packages-from=<version>] [--copy-packages-from=<version>] [--latest-npm] [--skip-default-packages] [--offline]
        \\  use [version] [--lts] [--silent] [--save]
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
        \\  reinstall-packages <version>
        \\  install-latest-npm
        \\  cache dir|clear
        \\  deactivate [--silent]
        \\  guide, interactive         menu (also: {s} with no arguments in a terminal)
        \\  registry [show|set-default|add|remove|china|official|sync]
        \\  mirror [ls|use|set|reset|test]
        \\  debug
        \\  env                        shell setup (eval "$({s} env)")
        \\  --version, -v              print the znvm version
        \\  help, --help
        \\
        \\Node versions are stored under $NVM_DIR/versions/node (default ~/.nvm).
        \\Downloads use $NVM_NODEJS_ORG_MIRROR when it is set, otherwise
        \\https://npmmirror.com/mirrors/node.
        \\Global npm packages belong to each Node version.
        \\Source builds (-s), io.js, and the retired "unstable" line are not supported.
        \\With no arguments in a terminal, {s} opens an interactive guide.
        \\Without a terminal it prints a short notice and exits.
        \\registry stores a default URL plus @scope routes in $NVM_DIR/registries.json.
        \\It writes ~/.npmrc, ~/.yarnrc, ~/.yarnrc.yml, the pnpm rc, and ~/.bunfig.toml.
        \\china sets https://registry.npmmirror.com and keeps scopes.
        \\official sets https://registry.npmjs.org and keeps scopes.
        \\Other lines in those files stay. A yarn npmScopes block is replaced by the saved scopes.
        \\use, ls, and current on this command always select Node versions.
        \\Named registries are the separate nrm command. nvm registry is the prefixed alias.
        \\mirror sets the Node dist host and download mirrors for Electron, Playwright,
        \\Cypress, puppeteer, sharp, node-sass, and other tools.
        \\It writes npm, pnpm, and yarn v1 keys, plus $NVM_DIR/binaries.env.
        \\A new shell sources that file. Scope routes are not changed.
        \\Docker image mirrors are not set here.
        \\
        \\Agents:
        \\  --json writes one JSON object to stdout for ls, ls-remote, current, which,
        \\  version, --version, mirror ls, and mirror test.
        \\  Other commands reject --json.
        \\  A --json error is {{"error":"...","exit":N}} on stderr, and stdout is empty.
        \\  --yes and NVM_NONINTERACTIVE=1 (also true or yes) never open a menu.
        \\  A non-empty CI does the same. NVM_NONINTERACTIVE=0 does not.
        \\  Menus need a terminal on stdin and on the menu stream.
        \\  --guide-step draws on stderr, so a piped stdout still works in a terminal.
        \\  NO_COLOR stays plain ASCII. Output has no color sequences.
        \\  Exit codes: 0 success, 1 usage or failure, 2 the guide quit,
        \\  3 no matching version, 8 an alias loop, 55 an unsupported option,
        \\  127 system node missing or a missing version file.
        \\
    , .{ program_name, program_name, program_name, program_name });
}

pub fn printNrmHelp() !void {
    try stdout(
        \\nrm - registry manager
        \\
        \\Commands:
        \\  ls
        \\  use <name|auto>
        \\  current [-u|--show-url]
        \\  add <name> <url>
        \\  del <name>
        \\  test [name]
        \\  scope ls
        \\  scope add <@scope> <url>
        \\  scope del <@scope>
        \\  help
        \\  --version, -v
        \\
        \\Built-in names: npm, yarn, tencent, cnpm, taobao, npmMirror, huawei.
        \\Custom names are stored in $NVM_DIR/registries.json.
        \\use and scope write ~/.npmrc, ~/.yarnrc, ~/.yarnrc.yml, the pnpm rc, and ~/.bunfig.toml.
        \\use auto picks the fastest healthy registry and leaves @scope routes unchanged.
        \\Download mirrors are the nvm mirror command.
        \\With no arguments in a terminal, nrm opens a menu for registries, scopes, and tests.
        \\Without a terminal it prints this help.
        \\--yes, NVM_NONINTERACTIVE=1 (also true or yes), and a non-empty CI do the same.
        \\--json writes one JSON object to stdout for ls, current, test, and scope ls.
        \\A --json error is {{"error":"...","exit":N}} on stderr, and stdout is empty.
        \\NO_COLOR stays plain ASCII.
        \\nvm registry edits the same map.
        \\
    , .{});
}

pub fn cmdNrm(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    const reg = @import("registry.zig");
    if (args.len < 2) {
        try printNrmHelp();
        return;
    }
    const sub = args[1];
    const failed = blk: {
        if ((mem.eql(u8, sub, "help") or mem.eql(u8, sub, "--help") or mem.eql(u8, sub, "-h")) and args.len == 2) {
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
            try stderr(
                \\registry show
                \\registry set-default <url>
                \\registry add <@scope> <url>
                \\registry remove <@scope>
                \\registry china
                \\registry official
                \\registry sync
                \\
            , .{});
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
    const root_dir = try shellQuote(allocator, config.root_dir);
    defer allocator.free(root_dir);

    var optional = std.ArrayList(u8){};
    defer optional.deinit(allocator);
    if (config.npm_prefix) |prefix| {
        const npm_bin_path = try fs.path.join(allocator, &.{ prefix, "bin" });
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
        const quoted_prefix = try shellQuote(allocator, prefix);
        defer allocator.free(quoted_prefix);
        const quoted_path = try shellQuote(allocator, path_list.items);
        defer allocator.free(quoted_path);
        try optional.print(allocator, "export NPM_CONFIG_PREFIX={s}\nexport PATH={s}\n", .{ quoted_prefix, quoted_path });
    }
    const optional_text = optional.items;

    const nvm_exe_raw = std.fs.selfExePathAlloc(allocator) catch try allocator.dupe(u8, "nvm");
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

fn requireSpec(allocator: mem.Allocator, parsed: *const ParsedArgs, usage: []const u8, silent: bool) ![]u8 {
    if (parsed.positionals.items.len > 1) failFmt(1, "{s}", .{usage});
    if (parsed.lts) |name| return ltsSpec(allocator, name);
    if (parsed.positionals.items.len == 1) return allocator.dupe(u8, parsed.positionals.items[0]);
    return try readNvmrcSpec(allocator, silent) orelse failFmt(127, "{s}\nNo .nvmrc or .node-version file found.", .{usage});
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
    if (parsed.save) {
        switch (hit) {
            .system => {
                try stderr("The system Node.js cannot be written to .nvmrc.\n", .{});
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

fn ensureTree(allocator: mem.Allocator, path: []const u8) !void {
    var acc = std.ArrayList(u8){};
    defer acc.deinit(allocator);
    var start: usize = 0;
    if (path.len > 0 and path[0] == '/') {
        try acc.append(allocator, '/');
        start = 1;
    }
    var it = mem.splitScalar(u8, path[start..], '/');
    while (it.next()) |part| {
        if (part.len == 0) continue;
        if (acc.items.len > 0 and acc.items[acc.items.len - 1] != '/') try acc.append(allocator, '/');
        try acc.appendSlice(allocator, part);
        try ensureDir(acc.items);
    }
}

fn fileNonEmpty(path: []const u8) bool {
    const file = fs.openFileAbsolute(path, .{}) catch return false;
    defer file.close();
    const stat = file.stat() catch return false;
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
    var list = std.ArrayList([]u8){};
    errdefer {
        for (list.items) |item| allocator.free(item);
        list.deinit(allocator);
    }
    const modules = try fs.path.join(allocator, &.{ version_dir, "lib", "node_modules" });
    defer allocator.free(modules);
    var dir = fs.openDirAbsolute(modules, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) return list.toOwnedSlice(allocator);
        return err;
    };
    defer dir.close();
    var it = dir.iterate();
    while (try it.next()) |entry| {
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
    const npm = try fs.path.join(allocator, &.{ home, "bin", "npm" });
    defer allocator.free(npm);
    fs.accessAbsolute(npm, .{}) catch {
        try stderr("npm was not found for {s}.\n", .{ver});
        process.exit(1);
    };
    const bin_path = try fs.path.join(allocator, &.{ home, "bin" });
    defer allocator.free(bin_path);

    var argv = std.ArrayList([]const u8){};
    defer argv.deinit(allocator);
    try argv.append(allocator, npm);
    try argv.append(allocator, "install");
    try argv.append(allocator, "-g");
    for (packages) |pkg| try argv.append(allocator, pkg);

    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();
    const inherited = env_map.get("PATH") orelse "";
    const path_value = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ bin_path, inherited });
    defer allocator.free(path_value);
    try env_map.put("PATH", path_value);
    if (config.npm_prefix) |prefix| {
        try env_map.put("NPM_CONFIG_PREFIX", prefix);
    } else {
        env_map.remove("NPM_CONFIG_PREFIX");
    }

    var child = process.Child.init(argv.items, allocator);
    child.env_map = &env_map;
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    const term = try child.spawnAndWait();
    const ok = switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };
    if (!ok) {
        try stderr("npm install -g failed for {s}.\n", .{ver});
        process.exit(1);
    }
}

fn reinstallPackages(allocator: mem.Allocator, config: ZnvmConfig, source_spec: []const u8, dest_ver: []const u8) !void {
    const source_hit = try resolveLocalOrExit(allocator, config, source_spec, null);
    defer source_hit.deinit(allocator);
    const source_ver = switch (source_hit) {
        .system => {
            try stderr("Reinstalling packages from the system Node.js is not supported.\n", .{});
            process.exit(1);
        },
        .version => |ver| ver,
    };
    if (mem.eql(u8, source_ver, dest_ver)) {
        try stderr("Can not reinstall packages from the current version of node.\n", .{});
        process.exit(2);
    }
    const source_dir = try versionHome(allocator, config, source_ver);
    defer allocator.free(source_dir);
    const names = try listGlobalPackages(allocator, source_dir);
    defer {
        for (names) |name| allocator.free(name);
        allocator.free(names);
    }
    try stderr("Reinstalling global packages from {s}...\n", .{source_ver});
    if (names.len == 0) {
        try stderr("No installed global packages found...\n", .{});
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

    var specs = std.ArrayList([]u8){};
    defer {
        for (specs.items) |item| allocator.free(item);
        specs.deinit(allocator);
    }
    var lines = mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw| {
        const line = mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        if (mem.indexOfScalar(u8, line, ' ') != null or mem.indexOfScalar(u8, line, '\t') != null) {
            try stderr("Only one package per line is allowed in `{s}`.\n", .{path});
            process.exit(1);
        }
        try specs.append(allocator, try allocator.dupe(u8, line));
    }
    if (specs.items.len == 0) return;
    if (!silent) try stderr("Installing default global packages from {s}...\n", .{path});
    const view = try allocator.alloc([]const u8, specs.items.len);
    defer allocator.free(view);
    for (specs.items, 0..) |item, index| view[index] = item;
    try npmInstallGlobal(allocator, config, ver, view);
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

    if (parsed.reinstall_from) |source| {
        const source_dir = try locateVersionDir(allocator, config, source) orelse {
            try stderr("If --reinstall-packages-from is provided, it must point to an installed version of node.\n", .{});
            process.exit(1);
        };
        allocator.free(source_dir);
    }

    const install_path = try newVersionDir(allocator, config, ver);
    defer allocator.free(install_path);
    const existing = try locateVersionDir(allocator, config, ver);
    defer if (existing) |dir_path| allocator.free(dir_path);
    if (existing != null) {
        if (!parsed.silent) try stderr("Version {s} is already installed.\n", .{ver});
    } else {
        if (!parsed.silent) try stderr("Installing {s} ({s})...\n", .{ ver, resolved.arch });
        const download_url = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ config.mirror, ver, resolved.filename });
        defer allocator.free(download_url);
        const tar_path = try fs.path.join(allocator, &.{ config.root_dir, ".cache", "bin", resolved.filename });
        defer allocator.free(tar_path);
        try ensureTree(allocator, fs.path.dirname(tar_path) orelse config.root_dir);
        if (!fileNonEmpty(tar_path)) {
            if (parsed.offline) {
                try stderr("No cached tarball for {s}. Run install once without --offline.\n", .{ver});
                process.exit(1);
            }
            try version.downloadFile(allocator, download_url, tar_path);
        } else if (!parsed.silent) {
            try stderr("Using cached {s}\n", .{resolved.filename});
        }
        if (!parsed.silent) try stderr("Extracting...\n", .{});
        try ensureTree(allocator, install_path);

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
    if (parsed.positionals.items.len > 1) failFmt(1, "Usage: {s} ls [version]", .{program_name});
    if (parsed.no_alias and parsed.positionals.items.len > 0) {
        failFmt(55, "`--no-alias` is not supported when a version is provided.", .{});
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
    if (parsed.positionals.items.len > 1) failFmt(1, "Usage: {s} ls-remote [version]", .{program_name});
    const raw = if (parsed.positionals.items.len == 1) parsed.positionals.items[0] else "";
    var query = version.parseVersionQuery(raw, parsed.lts);
    if (query.special == .current or query.special == .system or query.special == .default) try na();
    if (query.special == .latest) query.special = .none;
    const list_all = query.special == .none and query.lts == null and query.prefix.len == 0;

    const index = version.loadRemoteIndex(allocator, config) catch |err| {
        failFmt(1, "error: Failed to fetch Node.js index ({s})", .{@errorName(err)});
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
            const path = try locateVersionDir(allocator, config, ver) orelse {
                try stderr("Version '{s}' is not installed.\n", .{ver});
                process.exit(1);
            };
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
    const usage = try std.fmt.allocPrint(allocator, "Usage: {s} which [version]", .{program_name});
    defer allocator.free(usage);
    const spec = try requireSpec(allocator, &parsed, usage, parsed.silent);
    defer allocator.free(spec);
    const hit = try resolveLocalOrExit(allocator, config, spec, null);
    defer hit.deinit(allocator);
    switch (hit) {
        .system => {
            const node = try findSystemNode(allocator, config) orelse failFmt(127, "System version of node not found.", .{});
            defer allocator.free(node);
            try emitWhich(allocator, "system", node);
        },
        .version => |ver| {
            const home = try versionHome(allocator, config, ver);
            defer allocator.free(home);
            const node = try fs.path.join(allocator, &.{ home, "bin", "node" });
            defer allocator.free(node);
            fs.accessAbsolute(node, .{}) catch failFmt(1, "Version '{s}' is installed but bin/node is missing.", .{ver});
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
    if (parsed.positionals.items.len > 1) failFmt(1, "Usage: {s} version [version]", .{program_name});
    const spec = if (parsed.lts) |name| try ltsSpec(allocator, name) else try allocator.dupe(u8, parsed.positionals.items[0]);
    defer allocator.free(spec);
    const hit = resolveLocalSpec(allocator, config, spec, null, 0) catch |err| switch (err) {
        error.AliasCycle => failFmt(8, "The alias \"{s}\" leads to an infinite loop. Aborting.", .{spec}),
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
            const home = try versionHome(allocator, config, ver);
            defer allocator.free(home);
            const node_bin = try fs.path.join(allocator, &.{ home, "bin", "node" });
            defer allocator.free(node_bin);
            fs.accessAbsolute(node_bin, .{}) catch {
                try stderr("Version '{s}' is installed but bin/node is missing.\n", .{ver});
                process.exit(1);
            };
            const bin_path = try fs.path.join(allocator, &.{ home, "bin" });
            defer allocator.free(bin_path);
            const inc_path = try fs.path.join(allocator, &.{ home, "include", "node" });
            defer allocator.free(inc_path);
            try env_map.put("ZNVM_CURRENT", ver);
            if (config.npm_prefix) |prefix| {
                try env_map.put("NPM_CONFIG_PREFIX", prefix);
            } else {
                env_map.remove("NPM_CONFIG_PREFIX");
            }
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
            try stderr("Usage: {s} {s} [version] [args...]\nNo .nvmrc or .node-version file found.\n", .{ program_name, command_name });
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
        .version => |ver| blk: {
            const home = try versionHome(allocator, config, ver);
            defer allocator.free(home);
            break :blk try fs.path.join(allocator, &.{ home, "bin", "node" });
        },
    };
    defer allocator.free(node_bin);

    var argv = std.ArrayList([]const u8){};
    defer argv.deinit(allocator);
    try argv.append(allocator, node_bin);
    try argv.appendSlice(allocator, prepared.args);
    try runInHit(allocator, config, hit, argv.items, parsed.silent);
}

pub fn cmdReinstallPackages(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len != 1) {
        try stderr("Usage: {s} reinstall-packages <version>\n", .{program_name});
        process.exit(127);
    }
    const current = try getCurrentVersionFromPath(allocator, config) orelse {
        try stderr("No active Node.js version. Run `{s} use <version>` first.\n", .{program_name});
        process.exit(1);
    };
    defer allocator.free(current);
    try reinstallPackages(allocator, config, parsed.positionals.items[0], current);
}

pub fn cmdInstallLatestNpm(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    var parsed = try parseArgs(allocator, args[2..], .strict);
    defer parsed.deinit(allocator);
    if (parsed.positionals.items.len != 0) {
        try stderr("Usage: {s} install-latest-npm\n", .{program_name});
        process.exit(127);
    }
    const current = try getCurrentVersionFromPath(allocator, config) orelse {
        try stderr("No active Node.js version. Run `{s} use <version>` first.\n", .{program_name});
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
        try stderr("Usage: {s} cache dir|clear\n", .{program_name});
        process.exit(127);
    }
    const cache_dir = try fs.path.join(allocator, &.{ config.root_dir, ".cache" });
    defer allocator.free(cache_dir);
    if (mem.eql(u8, action, "dir")) {
        try stdout("{s}\n", .{cache_dir});
        return;
    }
    if (mem.eql(u8, action, "clear")) {
        fs.deleteTreeAbsolute(cache_dir) catch {};
        try ensureDir(cache_dir);
        try stdout("{s} cache cleared.\n", .{program_name});
        return;
    }
    try stderr("Usage: {s} cache dir|clear\n", .{program_name});
    process.exit(127);
}

pub fn cmdDebug(allocator: mem.Allocator, config: ZnvmConfig) !void {
    const installed = try version.getInstalledVersions(allocator, config);
    defer freeInstalled(allocator, installed);
    try stderr("znvm version: v2.7.0\n", .{});
    try stderr("NVM_DIR: {s}\n", .{config.root_dir});
    try stderr("versions: {s}\n", .{config.versions_dir});
    try stderr("mirror: {s}\n", .{config.mirror});
    try stderr("platform: {s}-{s}\n", .{ config.os, config.arch });
    try stderr("installed: {d}\n", .{installed.len});
    if (config.npm_prefix) |prefix| {
        try stderr("npm prefix: {s}\n", .{prefix});
    } else {
        try stderr("npm prefix: per Node version\n", .{});
    }
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
