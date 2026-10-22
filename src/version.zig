const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const util = @import("util.zig");
const ZnvmConfig = @import("config.zig").ZnvmConfig;

const stderr = util.stderr;

pub const NodeEntry = struct {
    version: []const u8,
    files: []const []const u8,
    lts: ?json.Value = null,
};

pub const ResolvedRemote = struct {
    version: []const u8,
    filename: []const u8,
    arch: []const u8,
};
pub const ResolvedEntry = struct {
    entry: NodeEntry,
    arch: []const u8,
};

fn platformFile(os: []const u8, arch: []const u8) ?[]const u8 {
    if (mem.eql(u8, os, "darwin")) {
        if (mem.eql(u8, arch, "arm64")) return "osx-arm64-tar";
        if (mem.eql(u8, arch, "x64")) return "osx-x64-tar";
    } else if (mem.eql(u8, os, "linux")) {
        if (mem.eql(u8, arch, "arm64")) return "linux-arm64";
        if (mem.eql(u8, arch, "x64")) return "linux-x64";
    }
    return null;
}

pub fn matchesVersionPrefix(version_text: []const u8, query: []const u8) bool {
    if (query.len == 0 or !mem.startsWith(u8, version_text, query)) return false;
    return version_text.len == query.len or version_text[query.len] == '.';
}

pub const VersionQuery = struct {
    special: enum { none, latest, current, system, default } = .none,
    /// "*" for any LTS line, or a codename such as "iron".
    lts: ?[]const u8 = null,
    /// Numeric prefix with the leading "v" removed. Empty when the query is not numeric.
    prefix: []const u8 = "",
};

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
    }
    return true;
}

pub fn parseVersionQuery(raw: []const u8, lts_flag: ?[]const u8) VersionQuery {
    var result = VersionQuery{};
    if (lts_flag) |flag| {
        result.lts = if (flag.len == 0 or mem.eql(u8, flag, "*")) "*" else flag;
    }

    const trimmed = mem.trim(u8, raw, " \t\r\n");
    if (trimmed.len == 0 or mem.eql(u8, trimmed, "--lts")) {
        if (mem.eql(u8, trimmed, "--lts")) result.lts = "*";
        return result;
    }
    if (mem.eql(u8, trimmed, "lts") or mem.eql(u8, trimmed, "lts/*")) {
        result.lts = "*";
        return result;
    }
    if (mem.startsWith(u8, trimmed, "lts/")) {
        const name = trimmed["lts/".len..];
        result.lts = if (name.len == 0 or mem.eql(u8, name, "*")) "*" else name;
        return result;
    }
    if (mem.eql(u8, trimmed, "node") or mem.eql(u8, trimmed, "stable") or mem.eql(u8, trimmed, "latest")) {
        result.special = .latest;
        return result;
    }
    if (mem.eql(u8, trimmed, "current")) {
        result.special = .current;
        return result;
    }
    if (mem.eql(u8, trimmed, "system")) {
        result.special = .system;
        return result;
    }
    if (mem.eql(u8, trimmed, "default")) {
        result.special = .default;
        return result;
    }

    var prefix = trimmed;
    if (mem.startsWith(u8, prefix, "v")) prefix = prefix[1..];
    result.prefix = prefix;
    return result;
}

/// True for selectors like `20`, `v20.11.0`, or `20.11.1-rc.1`. Aliases are handled separately.
pub fn looksLikeVersion(text: []const u8) bool {
    const query = parseVersionQuery(text, null);
    if (query.special != .none or query.lts != null) return true;
    const prefix = query.prefix;
    if (prefix.len == 0) return false;

    var i: usize = 0;
    var dots: u8 = 0;
    var saw_digit = false;
    while (i < prefix.len) : (i += 1) {
        const char = prefix[i];
        if (char == '.') {
            if (!saw_digit or dots == 2) return false;
            dots += 1;
            saw_digit = false;
            continue;
        }
        if (char == '-') {
            if (dots != 2 or !saw_digit or i + 1 == prefix.len) return false;
            return true;
        }
        if (char < '0' or char > '9') return false;
        saw_digit = true;
    }
    return saw_digit;
}

pub fn entryLtsName(entry: NodeEntry) ?[]const u8 {
    const lts = entry.lts orelse return null;
    return switch (lts) {
        .string => |name| if (name.len == 0) null else name,
        else => null,
    };
}

pub fn entryMatchesLts(entry: NodeEntry, codename: []const u8) bool {
    const lts = entry.lts orelse return false;
    return switch (lts) {
        .bool => |enabled| enabled and (codename.len == 0 or mem.eql(u8, codename, "*")),
        .string => |name| if (codename.len == 0 or mem.eql(u8, codename, "*")) true else eqlIgnoreCase(name, codename),
        else => false,
    };
}

fn entryHasFile(entry: NodeEntry, required_file: []const u8) bool {
    for (entry.files) |file| {
        if (mem.eql(u8, file, required_file)) return true;
    }
    return false;
}

pub fn isInstallable(entry: NodeEntry, os: []const u8, arch: []const u8) bool {
    const native = platformFile(os, arch) orelse return false;
    if (entryHasFile(entry, native)) return true;
    if (mem.eql(u8, os, "darwin") and mem.eql(u8, arch, "arm64")) {
        return entryHasFile(entry, "osx-x64-tar");
    }
    return false;
}

pub fn entryMatchesQuery(entry: NodeEntry, query: VersionQuery) bool {
    if (entry.version.len < 2 or entry.version[0] != 'v') return false;
    if (query.lts) |codename| {
        if (!entryMatchesLts(entry, codename)) return false;
    }
    return switch (query.special) {
        .latest => query.prefix.len == 0 or matchesVersionPrefix(entry.version[1..], query.prefix),
        .current, .system, .default => false,
        .none => if (query.prefix.len == 0) query.lts != null else matchesVersionPrefix(entry.version[1..], query.prefix),
    };
}

fn entryMatchesRemote(entry: NodeEntry, query: VersionQuery, required_file: []const u8) bool {
    if (!entryHasFile(entry, required_file)) return false;
    return entryMatchesQuery(entry, query);
}

pub fn resolveRemoteEntryQuery(entries: []const NodeEntry, query: VersionQuery, required_file: []const u8) ?NodeEntry {
    if (query.special == .current or query.special == .system or query.special == .default) return null;
    if (query.special == .none and query.lts == null and query.prefix.len == 0) return null;

    var best_entry: ?NodeEntry = null;
    var best_semver: ?std.SemanticVersion = null;

    for (entries) |entry| {
        if (!entryMatchesRemote(entry, query, required_file)) continue;
        const semver = std.SemanticVersion.parse(entry.version[1..]) catch continue;
        if (best_semver == null or semver.order(best_semver.?) == .gt) {
            best_semver = semver;
            best_entry = entry;
        }
    }

    return best_entry;
}

pub fn resolveRemoteEntry(entries: []const NodeEntry, query: []const u8, required_file: []const u8) ?NodeEntry {
    return resolveRemoteEntryQuery(entries, parseVersionQuery(query, null), required_file);
}

pub fn resolveRemoteArtifactQuery(entries: []const NodeEntry, query: VersionQuery, os: []const u8, arch: []const u8) ?ResolvedEntry {
    const required_file = platformFile(os, arch) orelse return null;
    if (resolveRemoteEntryQuery(entries, query, required_file)) |entry| {
        return .{ .entry = entry, .arch = arch };
    }

    if (mem.eql(u8, os, "darwin") and mem.eql(u8, arch, "arm64")) {
        if (resolveRemoteEntryQuery(entries, query, "osx-x64-tar")) |entry| {
            return .{ .entry = entry, .arch = "x64" };
        }
    }
    return null;
}

pub fn resolveRemoteArtifact(entries: []const NodeEntry, query: []const u8, os: []const u8, arch: []const u8) ?ResolvedEntry {
    return resolveRemoteArtifactQuery(entries, parseVersionQuery(query, null), os, arch);
}

fn writeIndexCache(path: []const u8, body: []const u8) !void {
    if (fs.path.dirname(path)) |dir| {
        if (fs.path.dirname(dir)) |root| {
            fs.makeDirAbsolute(root) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }
        fs.makeDirAbsolute(dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(body);
}

fn readIndexCache(allocator: mem.Allocator, path: []const u8) ![]u8 {
    const file = try fs.openFileAbsolute(path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, 10 * 1024 * 1024);
}

fn fetchIndexBody(allocator: mem.Allocator, config: ZnvmConfig) ![]u8 {
    const index_url = try std.fmt.allocPrint(allocator, "{s}/index.json", .{config.mirror});
    defer allocator.free(index_url);
    const cache_path = try fs.path.join(allocator, &.{ config.root_dir, "cache", "index.json" });
    defer allocator.free(cache_path);

    const argv = &[_][]const u8{ "curl", "-fsSL", index_url };
    if (process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 10 * 1024 * 1024,
    })) |result| {
        defer allocator.free(result.stderr);
        const ok = switch (result.term) {
            .Exited => |code| code == 0 and result.stdout.len > 0,
            else => false,
        };
        if (ok) {
            writeIndexCache(cache_path, result.stdout) catch {};
            return result.stdout;
        }
        allocator.free(result.stdout);
    } else |_| {}

    return readIndexCache(allocator, cache_path);
}

pub fn parseIndex(allocator: mem.Allocator, body: []const u8) !json.Parsed([]NodeEntry) {
    // Strings must be copied. The index body is freed as soon as parsing returns,
    // and the default parse option keeps slices pointing into that buffer.
    return json.parseFromSlice([]NodeEntry, allocator, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
}

pub fn loadRemoteIndex(allocator: mem.Allocator, config: ZnvmConfig) !json.Parsed([]NodeEntry) {
    const body = try fetchIndexBody(allocator, config);
    defer allocator.free(body);
    return parseIndex(allocator, body);
}

fn artifactToRemote(allocator: mem.Allocator, artifact: ResolvedEntry, os: []const u8) !ResolvedRemote {
    const entry = artifact.entry;
    const os_name = if (mem.eql(u8, os, "darwin")) "darwin" else os;
    const filename = try std.fmt.allocPrint(allocator, "node-{s}-{s}-{s}.tar.gz", .{ entry.version, os_name, artifact.arch });
    return ResolvedRemote{
        .version = try allocator.dupe(u8, entry.version),
        .filename = filename,
        .arch = artifact.arch,
    };
}

pub fn resolveRemoteQuery(allocator: mem.Allocator, query: VersionQuery, config: ZnvmConfig) !?ResolvedRemote {
    const parsed = loadRemoteIndex(allocator, config) catch |err| {
        try stderr("Failed to fetch Node.js index ({s})\n", .{@errorName(err)});
        return null;
    };
    defer parsed.deinit();

    const artifact = resolveRemoteArtifactQuery(parsed.value, query, config.os, config.arch) orelse return null;
    return try artifactToRemote(allocator, artifact, config.os);
}

pub fn resolveRemoteVersion(allocator: mem.Allocator, query: []const u8, config: ZnvmConfig) !?ResolvedRemote {
    return resolveRemoteQuery(allocator, parseVersionQuery(query, null), config);
}

pub fn downloadFile(allocator: mem.Allocator, url: []const u8, dest_path: []const u8) !void {
    const argv = &[_][]const u8{ "curl", "-sSL", "-o", dest_path, url };
    const result = try process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const downloaded = switch (result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
    if (!downloaded) return error.DownloadFailed;
}

/// nvm stores Node older than 0.12 directly in `$NVM_DIR`, not `versions/node`.
pub fn isOldNodeLayout(ver: []const u8) bool {
    const numeric = if (ver.len > 0 and ver[0] == 'v') ver[1..] else ver;
    const parsed = std.SemanticVersion.parse(numeric) catch return false;
    const cutoff = std.SemanticVersion{ .major = 0, .minor = 12, .patch = 0 };
    return parsed.order(cutoff) == .lt;
}

fn alreadyListed(list: []const []const u8, name: []const u8) bool {
    for (list) |item| if (mem.eql(u8, item, name)) return true;
    return false;
}

pub fn getInstalledVersions(allocator: mem.Allocator, config: ZnvmConfig) ![]const []const u8 {
    var list = std.ArrayList([]const u8){};

    for (config.scan_dirs) |dir_path| {
        var dir = fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) continue;
            return err;
        };
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .directory or !mem.startsWith(u8, entry.name, "v")) continue;
            if (alreadyListed(list.items, entry.name)) continue;
            const node_path = try fs.path.join(allocator, &.{ dir_path, entry.name, "bin", "node" });
            defer allocator.free(node_path);
            fs.accessAbsolute(node_path, .{}) catch continue;
            try list.append(allocator, try allocator.dupe(u8, entry.name));
        }
    }

    const Sorter = struct {
        pub fn less(context: void, lhs: []const u8, rhs: []const u8) bool {
            _ = context;
            const v1 = std.SemanticVersion.parse(lhs[1..]) catch return false;
            const v2 = std.SemanticVersion.parse(rhs[1..]) catch return true;
            return v1.order(v2) == .lt;
        }
    };
    mem.sort([]const u8, list.items, {}, Sorter.less);

    return list.toOwnedSlice(allocator);
}

pub fn findExactInstalled(installed: []const []const u8, query: []const u8) ?[]const u8 {
    for (installed) |ver| {
        if (mem.eql(u8, ver, query)) return ver;
    }
    const numeric = if (mem.startsWith(u8, query, "v")) query[1..] else query;
    for (installed) |ver| {
        if (ver.len == numeric.len + 1 and ver[0] == 'v' and mem.eql(u8, ver[1..], numeric)) return ver;
    }
    return null;
}

pub fn latestInstalled(installed: []const []const u8, prefix: []const u8) ?[]const u8 {
    var best: ?[]const u8 = null;
    var best_semver: ?std.SemanticVersion = null;
    for (installed) |ver| {
        if (ver.len < 2 or ver[0] != 'v') continue;
        if (prefix.len > 0 and !matchesVersionPrefix(ver[1..], prefix)) continue;
        const semver = std.SemanticVersion.parse(ver[1..]) catch continue;
        if (best_semver == null or semver.order(best_semver.?) == .gt) {
            best = ver;
            best_semver = semver;
        }
    }
    return best;
}

/// Returns the version selector inside an `.nvmrc` body, or null when the file is empty or invalid.
/// The result is a slice of `content`.
pub fn parseNvmrc(content: []const u8) ?[]const u8 {
    var lines = mem.splitScalar(u8, content, '\n');
    var found: ?[]const u8 = null;
    while (lines.next()) |raw_line| {
        var line = raw_line;
        if (mem.indexOfScalar(u8, line, '#')) |hash| line = line[0..hash];
        line = mem.trim(u8, line, " \t\r");
        if (line.len == 0 or mem.indexOfScalar(u8, line, '=') != null) continue;
        if (found != null) return null;
        found = line;
    }
    return found;
}

pub fn resolveLocalVersion(allocator: mem.Allocator, installed: []const []const u8, query: []const u8) !?[]const u8 {
    for (installed) |ver| {
        if (mem.eql(u8, ver, query)) return ver;
    }

    if (mem.startsWith(u8, query, "v")) {
        for (installed) |ver| {
            if (mem.eql(u8, ver, query)) return ver;
        }
    } else {
        const v_query = try std.fmt.allocPrint(allocator, "v{s}", .{query});
        defer allocator.free(v_query);
        for (installed) |ver| {
            if (mem.eql(u8, ver, v_query)) return ver;
        }
    }

    var best: ?[]const u8 = null;
    var best_semver: ?std.SemanticVersion = null;

    var clean_query = query;
    if (mem.startsWith(u8, query, "v")) clean_query = query[1..];

    for (installed) |ver| {
        if (ver.len < 2 or ver[0] != 'v') continue;
        const ver_num = ver[1..];
        if (!matchesVersionPrefix(ver_num, clean_query)) continue;
        const semver = std.SemanticVersion.parse(ver_num) catch continue;
        if (best_semver == null or semver.order(best_semver.?) == .gt) {
            best = ver;
            best_semver = semver;
        }
    }

    return best;
}
