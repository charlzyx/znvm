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

/// Emit ASCII-only code, not a quoted literal. PowerShell also recognizes
/// Unicode smart quotes as delimiters, and console code pages vary by host.
pub fn powerShellValue(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    const encoder = std.base64.standard.Encoder;
    const encoded = try allocator.alloc(u8, encoder.calcSize(value.len));
    defer allocator.free(encoded);
    _ = encoder.encode(encoded, value);
    return std.fmt.allocPrint(allocator, "([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{s}')))", .{encoded});
}

test "PowerShell values are ASCII-only expressions with literal UTF8 payload" {
    const allocator = std.testing.allocator;
    const value = "中文‘’; $(exit 42)\n'";
    const expression = try powerShellValue(allocator, value);
    defer allocator.free(expression);
    for (expression) |c| try std.testing.expect(c < 128);
    try std.testing.expect(std.mem.indexOf(u8, expression, "$(exit") == null);
    const prefix = "([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('";
    const encoded = expression[prefix.len .. expression.len - 4];
    const decoder = std.base64.standard.Decoder;
    const decoded = try allocator.alloc(u8, try decoder.calcSizeForSlice(encoded));
    defer allocator.free(decoded);
    try decoder.decode(decoded, encoded);
    try std.testing.expectEqualStrings(value, decoded);
}
