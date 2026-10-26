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

pub const Shell = enum { powershell, cmd, bash };
pub const EnvChange = struct { key: []const u8, value: ?[]const u8 };

pub fn parseShell(value: []const u8) !Shell {
    inline for (.{ Shell.powershell, Shell.cmd, Shell.bash }) |shell| {
        if (std.mem.eql(u8, value, @tagName(shell))) return shell;
    }
    return error.UnsupportedShell;
}

pub fn base64Value(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    const encoder = std.base64.standard.Encoder;
    const result = try allocator.alloc(u8, encoder.calcSize(value.len));
    _ = encoder.encode(result, value);
    return result;
}

fn allowedEnvKey(key: []const u8) bool {
    inline for (.{ "PATH", "NVM_DIR", "ZNVM_CURRENT", "NVM_BIN", "NVM_INC", "NPM_CONFIG_PREFIX" }) |allowed| {
        if (std.mem.eql(u8, key, allowed)) return true;
    }
    return false;
}

/// CMD only: generated batch is directly chained, never passed through CALL.
/// Caller must have delayed expansion disabled. Preflight every assignment
/// before returning any bytes, including cmd.exe's UTF-16 line-length budget.
pub fn cmdBatch(allocator: std.mem.Allocator, changes: []const EnvChange) ![]u8 {
    var body: std.ArrayList(u8) = .empty;
    errdefer body.deinit(allocator);
    try body.appendSlice(allocator, "@if \"%~1\"==\"\" exit /b 56\r\n" ++
        "@if not exist \"%~1\" exit /b 56\r\n" ++
        "@set _znvm_old_cp=\r\n" ++
        "@for /f \"tokens=2 delims=:\" %%C in ('\"\"%SystemRoot%\\System32\\chcp.com\"\"') do @set _znvm_old_cp=%%C\r\n" ++
        "@if not defined _znvm_old_cp goto znvm_codepage_failed\r\n" ++
        "@\"%SystemRoot%\\System32\\chcp.com\" 65001 >nul\r\n" ++
        "@if errorlevel 1 goto znvm_codepage_failed\r\n");
    for (changes) |change| {
        if (!allowedEnvKey(change.key)) return error.InvalidEnvironmentKey;
        const start = body.items.len;
        try body.appendSlice(allocator, "@set ");
        try body.appendSlice(allocator, change.key);
        try body.append(allocator, '=');
        if (change.value) |value| {
            for (value) |c| {
                if (c == 0 or c == '\r' or c == '\n') return error.InvalidCmdEnvironmentValue;
                if (c == '%') {
                    try body.appendSlice(allocator, "%%");
                } else {
                    if (std.mem.indexOfScalar(u8, "^&|<>()\"", c) != null) try body.append(allocator, '^');
                    try body.append(allocator, c);
                }
            }
        }
        const wide = try std.unicode.utf8ToUtf16LeAlloc(allocator, body.items[start..]);
        defer allocator.free(wide);
        if (wide.len > 8000) return error.CmdEnvironmentTooLong;
        try body.appendSlice(allocator, "\r\n");
    }
    try body.appendSlice(allocator, "@\"%SystemRoot%\\System32\\chcp.com\" %_znvm_old_cp% >nul\r\n" ++
        "@if errorlevel 1 goto znvm_codepage_failed\r\n" ++
        "@set _znvm_old_cp=\r\n" ++
        "@\"%~1\" \"%~f0\" 0\r\n" ++
        ":znvm_codepage_failed\r\n" ++
        "@if defined _znvm_old_cp \"%SystemRoot%\\System32\\chcp.com\" %_znvm_old_cp% >nul\r\n" ++
        "@set _znvm_old_cp=\r\n" ++
        "@\"%~1\" \"%~f0\" 1\r\n");
    return body.toOwnedSlice(allocator);
}

test "cmd output preflights all values and escapes one batch parse" {
    const a = std.testing.allocator;
    const batch = try cmdBatch(a, &.{.{ .key = "PATH", .value = "中文 %PATH% !bang! ^ & (x)" }});
    defer a.free(batch);
    try std.testing.expect(std.mem.indexOf(u8, batch, "@\"%~1\" \"%~f0\" 0\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, batch, "@\"%~1\" \"%~f0\" 1\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, batch, "@del ") == null);
    try std.testing.expect(std.mem.indexOf(u8, batch, "中文 %%PATH%% !bang! ^^ ^& ^(x^)") != null);
    try std.testing.expectError(error.InvalidCmdEnvironmentValue, cmdBatch(a, &.{.{ .key = "PATH", .value = "bad\r\necho bad" }}));
    try std.testing.expectError(error.InvalidEnvironmentKey, cmdBatch(a, &.{.{ .key = "BAD&echo", .value = "x" }}));
    const long = try a.alloc(u8, 8001);
    defer a.free(long);
    @memset(long, 'a');
    try std.testing.expectError(error.CmdEnvironmentTooLong, cmdBatch(a, &.{.{ .key = "PATH", .value = long }}));
}

pub fn sameWindowsPath(a: []const u8, b: []const u8) bool {
    var left = a;
    var right = b;
    while (left.len > 3 and (left[left.len - 1] == '/' or left[left.len - 1] == '\\')) left = left[0 .. left.len - 1];
    while (right.len > 3 and (right[right.len - 1] == '/' or right[right.len - 1] == '\\')) right = right[0 .. right.len - 1];
    if (left.len != right.len) return false;
    for (left, right) |x, y| {
        if ((x == '/' or x == '\\') and (y == '/' or y == '\\')) continue;
        if (std.ascii.toLower(x) != std.ascii.toLower(y)) return false;
    }
    return true;
}

test "shell names are explicit and Windows PATH dedup normalizes separators" {
    try std.testing.expectEqual(Shell.cmd, try parseShell("cmd"));
    try std.testing.expectEqual(Shell.bash, try parseShell("bash"));
    try std.testing.expectEqual(Shell.powershell, try parseShell("powershell"));
    try std.testing.expectError(error.UnsupportedShell, parseShell("pwsh"));
    try std.testing.expectError(error.UnsupportedShell, parseShell("cmd & echo bad"));
    try std.testing.expect(sameWindowsPath("C:/Package/CMD/", "c:\\package\\cmd"));
    try std.testing.expect(!sameWindowsPath("C:/Package/CMD-other", "c:\\package\\cmd"));
}
