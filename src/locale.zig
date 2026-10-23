const std = @import("std");
const host = @import("host.zig");
const builtin = @import("builtin");
const mem = std.mem;

/// First non-empty of NVM_LANG, LC_ALL, LC_MESSAGES, LANG.
/// `null` means none of those were set, so the caller may ask macOS.
pub fn decideZh(nvm_lang: ?[]const u8, lc_all: ?[]const u8, lc_messages: ?[]const u8, lang: ?[]const u8) ?bool {
    const values = [_]?[]const u8{ nvm_lang, lc_all, lc_messages, lang };
    for (values) |maybe| {
        const value = maybe orelse continue;
        if (value.len == 0) continue;
        return isZhTag(value);
    }
    return null;
}

pub fn isZhTag(value: []const u8) bool {
    if (value.len == 0) return false;
    if (mem.eql(u8, value, "C") or mem.eql(u8, value, "POSIX")) return false;
    return mem.startsWith(u8, value, "zh");
}

/// First double-quoted token in `defaults read -g AppleLanguages` output.
pub fn firstQuoted(text: []const u8) ?[]const u8 {
    const start = mem.indexOfScalar(u8, text, '"') orelse return null;
    const rest = text[start + 1 ..];
    const end = mem.indexOfScalar(u8, rest, '"') orelse return null;
    if (end == 0) return null;
    return rest[0..end];
}

pub fn preferZh(allocator: mem.Allocator) bool {
    var env = host.envMap(allocator) catch return false;
    defer env.deinit();
    if (decideZh(env.get("NVM_LANG"), env.get("LC_ALL"), env.get("LC_MESSAGES"), env.get("LANG"))) |zh| {
        return zh;
    }
    if (comptime builtin.os.tag != .macos) return false;
    return macPreferredZh(allocator);
}

fn macPreferredZh(allocator: mem.Allocator) bool {
    if (readDefaults(allocator, "AppleLanguages")) |text| {
        defer allocator.free(text);
        if (firstQuoted(text)) |lang| return isZhTag(lang);
    }
    if (readDefaults(allocator, "AppleLocale")) |text| {
        defer allocator.free(text);
        const trimmed = mem.trim(u8, text, " \t\r\n");
        if (trimmed.len == 0) return false;
        const end = mem.indexOfAny(u8, trimmed, " \t@") orelse trimmed.len;
        if (end == 0) return false;
        return isZhTag(trimmed[0..end]);
    }
    return false;
}

fn readDefaults(allocator: mem.Allocator, key: []const u8) ?[]u8 {
    const result = host.run(allocator, &.{ "defaults", "read", "-g", key }, 8192) catch return null;
    defer allocator.free(result.stderr);
    const exited = switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!exited) {
        allocator.free(result.stdout);
        return null;
    }
    return result.stdout;
}
