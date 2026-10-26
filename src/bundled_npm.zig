const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const host = @import("host.zig");

/// Reads the `version` field from `<version_home>/lib/node_modules/npm/package.json`.
pub fn readVersion(allocator: mem.Allocator, version_home: []const u8) !?[]u8 {
    const pkg_path = try fs.path.join(allocator, if (@import("builtin").os.tag == .windows) &.{ version_home, "node_modules", "npm", "package.json" } else &.{ version_home, "lib", "node_modules", "npm", "package.json" });
    defer allocator.free(pkg_path);
    const content = try readSmallFile(allocator, pkg_path) orelse return null;
    defer allocator.free(content);
    const parsed = std.json.parseFromSlice(
        struct { version: []const u8 },
        allocator,
        content,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    ) catch return null;
    defer parsed.deinit();
    if (parsed.value.version.len == 0) return null;
    return try allocator.dupe(u8, parsed.value.version);
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
