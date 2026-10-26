//! Native layout and environment differences. No symlinks or global PATH edits.
const std = @import("std");
pub const windows = @import("builtin").os.tag == .windows;
pub const path_delimiter: u8 = if (windows) ';' else ':';
pub const node_name = if (windows) "node.exe" else "node";
pub fn home(env: *const @import("host.zig").EnvMap) ?[]const u8 {
    return env.get("HOME") orelse (if (windows) env.get("USERPROFILE") else null);
}
pub fn binDir(allocator: std.mem.Allocator, dir: []const u8) ![]u8 {
    return if (windows) allocator.dupe(u8, dir) else std.fs.path.join(allocator, &.{ dir, "bin" });
}
pub fn nodePath(allocator: std.mem.Allocator, dir: []const u8) ![]u8 {
    return if (windows) std.fs.path.join(allocator, &.{ dir, node_name }) else std.fs.path.join(allocator, &.{ dir, "bin", node_name });
}
pub fn isSep(c: u8) bool {
    return c == '/' or (windows and c == '\\');
}
pub fn pathPrefix(path: []const u8, prefix: []const u8) bool {
    if (path.len < prefix.len) return false;
    for (path[0..prefix.len], prefix) |a, b| {
        if (isSep(a) and isSep(b)) continue;
        if (windows) {
            if (std.ascii.toLower(a) != std.ascii.toLower(b)) return false;
        } else if (a != b) return false;
    }
    return true;
}

test "native Node layout and PATH separator" {
    const allocator = std.testing.allocator;
    const dir = try binDir(allocator, "version");
    defer allocator.free(dir);
    const node = try nodePath(allocator, "version");
    defer allocator.free(node);
    try std.testing.expectEqualStrings(if (windows) "version" else "version/bin", dir);
    try std.testing.expectEqualStrings(if (windows) "version\\node.exe" else "version/bin/node", node);
    try std.testing.expectEqual(@as(u8, if (windows) ';' else ':'), path_delimiter);
    if (windows) {
        try std.testing.expect(pathPrefix("C:\\Users\\Name\\.nvm", "c:/users/name"));
        try std.testing.expect(!pathPrefix("C:\\Other", "c:/users"));
    }
}
