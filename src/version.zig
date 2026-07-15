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

fn matchesVersionPrefix(version_text: []const u8, query: []const u8) bool {
    if (query.len == 0 or !mem.startsWith(u8, version_text, query)) return false;
    return version_text.len == query.len or version_text[query.len] == '.';
}

pub fn resolveRemoteEntry(entries: []const NodeEntry, query: []const u8, required_file: []const u8) ?NodeEntry {
    var clean_query = query;
    if (mem.startsWith(u8, query, "v")) clean_query = query[1..];

    const is_lts = mem.eql(u8, clean_query, "lts") or mem.eql(u8, clean_query, "--lts");
    const is_latest = mem.eql(u8, clean_query, "latest") or mem.eql(u8, clean_query, "node") or mem.eql(u8, clean_query, "current");
    if (clean_query.len == 0) return null;

    var best_entry: ?NodeEntry = null;
    var best_semver: ?std.SemanticVersion = null;

    for (entries) |entry| {
        var has_file = false;
        for (entry.files) |file| {
            if (mem.eql(u8, file, required_file)) {
                has_file = true;
                break;
            }
        }
        if (!has_file or entry.version.len < 2 or entry.version[0] != 'v') continue;

        const semver = std.SemanticVersion.parse(entry.version[1..]) catch continue;
        const matches = if (is_lts) lts: {
            const lts = entry.lts orelse break :lts false;
            break :lts switch (lts) {
                .bool => |enabled| enabled,
                .string => true,
                else => false,
            };
        } else if (is_latest)
            true
        else
            matchesVersionPrefix(entry.version[1..], clean_query);

        if (matches and (best_semver == null or semver.order(best_semver.?) == .gt)) {
            best_semver = semver;
            best_entry = entry;
        }
    }

    return best_entry;
}
pub fn resolveRemoteArtifact(entries: []const NodeEntry, query: []const u8, os: []const u8, arch: []const u8) ?ResolvedEntry {
    const required_file = platformFile(os, arch) orelse return null;
    if (resolveRemoteEntry(entries, query, required_file)) |entry| {
        return .{ .entry = entry, .arch = arch };
    }

    if (mem.eql(u8, os, "darwin") and mem.eql(u8, arch, "arm64")) {
        if (resolveRemoteEntry(entries, query, "osx-x64-tar")) |entry| {
            return .{ .entry = entry, .arch = "x64" };
        }
    }
    return null;
}

pub fn resolveRemoteVersion(allocator: mem.Allocator, query: []const u8, config: ZnvmConfig) !?ResolvedRemote {
    const index_url = try std.fmt.allocPrint(allocator, "{s}/index.json", .{config.mirror});
    defer allocator.free(index_url);

    // Use curl as a fallback/alternative approach for fetching
    const argv = &[_][]const u8{ "curl", "-sSL", index_url };
    const result = try process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 10 * 1024 * 1024,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        try stderr("Failed to fetch index.json from {s}\n", .{index_url});
        return null;
    }

    const body_content = result.stdout;

    const parsed = try json.parseFromSlice([]NodeEntry, allocator, body_content, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const artifact = resolveRemoteArtifact(parsed.value, query, config.os, config.arch);

    if (artifact) |resolved| {
        const entry = resolved.entry;
        const os_name = if (mem.eql(u8, config.os, "darwin")) "darwin" else config.os;
        const filename = try std.fmt.allocPrint(allocator, "node-{s}-{s}-{s}.tar.gz", .{ entry.version, os_name, resolved.arch });

        return ResolvedRemote{
            .version = try allocator.dupe(u8, entry.version),
            .filename = filename,
            .arch = resolved.arch,
        };
    }

    return null;
}

pub fn downloadFile(allocator: mem.Allocator, url: []const u8, dest_path: []const u8) !void {
    const argv = &[_][]const u8{ "curl", "-sSL", "-o", dest_path, url };
    const result = try process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        return error.DownloadFailed;
    }
}

pub fn getInstalledVersions(allocator: mem.Allocator, config: ZnvmConfig) ![]const []const u8 {
    var list = std.ArrayList([]const u8){};

    var dir = fs.openDirAbsolute(config.versions_dir, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) return &.{};
        return err;
    };
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind == .directory) {
            if (mem.startsWith(u8, entry.name, "v")) {
                try list.append(allocator, try allocator.dupe(u8, entry.name));
            }
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
