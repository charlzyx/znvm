const std = @import("std");
const http = std.http;
const json = std.json;
const mem = std.mem;
const fs = std.fs;
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
};

pub fn resolveRemoteVersion(allocator: mem.Allocator, query: []const u8, config: ZnvmConfig) !?ResolvedRemote {
    const index_url = try std.fmt.allocPrint(allocator, "{s}/index.json", .{config.mirror});
    defer allocator.free(index_url);
    
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();
    
    const uri = try std.Uri.parse(index_url);
    var req = try client.request(.GET, uri, .{});
    defer req.deinit();
    
    try req.sendBodiless();
    var response = try req.receiveHead(&.{});
    
    if (response.head.status != .ok) {
        try stderr("Failed to fetch index.json: status {}\n", .{response.head.status});
        return null;
    }
    
    var buf: [4096]u8 = undefined;
    const reader = response.reader(&buf);
    
    const body_content = try reader.allocRemaining(allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(body_content);
    
    const parsed = try json.parseFromSlice([]NodeEntry, allocator, body_content, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    
    var best_entry: ?NodeEntry = null;
    var best_semver: ?std.SemanticVersion = null;
    
    var clean_query = query;
    if (mem.startsWith(u8, query, "v")) clean_query = query[1..];
    
    const is_lts = mem.eql(u8, clean_query, "lts") or mem.eql(u8, clean_query, "--lts");
    const is_latest = mem.eql(u8, clean_query, "latest") or mem.eql(u8, clean_query, "node") or mem.eql(u8, clean_query, "current");

    const required_file = if (mem.eql(u8, config.os, "darwin")) 
        try std.fmt.allocPrint(allocator, "osx-{s}-tar", .{config.arch})
    else
        try std.fmt.allocPrint(allocator, "{s}-{s}", .{config.os, config.arch});
    defer allocator.free(required_file);

    for (parsed.value) |entry| {
        var has_file = false;
        for (entry.files) |f| {
            if (mem.eql(u8, f, required_file)) {
                has_file = true;
                break;
            }
        }
        if (!has_file) continue;
        
        const ver_str = entry.version[1..];
        const semver = std.SemanticVersion.parse(ver_str) catch continue;
        
        var matches = false;
        
        if (is_lts) {
            if (entry.lts) |lts| {
                switch (lts) {
                    .bool => |b| if (b) { matches = true; },
                    .string => |_| { matches = true; }, 
                    else => {},
                }
            }
        } else if (is_latest) {
            matches = true;
        } else {
             if (mem.startsWith(u8, ver_str, clean_query)) {
                if (ver_str.len == clean_query.len) {
                    matches = true;
                } else if (ver_str[clean_query.len] == '.') {
                    matches = true;
                }
            }
        }
        
        if (matches) {
            if (best_semver == null or semver.order(best_semver.?) == .gt) {
                best_semver = semver;
                best_entry = entry;
            }
        }
    }
    
    if (best_entry) |entry| {
        const os_name = if (mem.eql(u8, config.os, "darwin")) "darwin" else config.os;
        const filename = try std.fmt.allocPrint(allocator, "node-{s}-{s}-{s}.tar.gz", .{entry.version, os_name, config.arch});
        
        return ResolvedRemote{
            .version = try allocator.dupe(u8, entry.version),
            .filename = filename,
        };
    }
    
    return null;
}

pub fn downloadFile(allocator: mem.Allocator, url: []const u8, dest_path: []const u8) !void {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();
    
    const uri = try std.Uri.parse(url);
    
    var req = try client.request(.GET, uri, .{});
    defer req.deinit();
    
    try req.sendBodiless();
    var response = try req.receiveHead(&.{});
    
    if (response.head.status != .ok) {
        return error.DownloadFailed;
    }
    
    var buf: [4096]u8 = undefined;
    const reader = response.reader(&buf);
    
    const file = try fs.createFileAbsolute(dest_path, .{});
    defer file.close();
    
    var file_buf: [4096]u8 = undefined;
    var file_writer_impl = file.writer(&file_buf);
    const w = &file_writer_impl.interface;
    
    _ = try reader.streamRemaining(w);
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
    
    var clean_query = query;
    if (mem.startsWith(u8, query, "v")) clean_query = query[1..];
    
    for (installed) |ver| {
        const ver_num = ver[1..]; 
        if (mem.startsWith(u8, ver_num, clean_query)) {
             best = ver;
        }
    }
    
    return best;
}
