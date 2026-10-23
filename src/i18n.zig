const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;

const host = @import("host.zig");
const locale = @import("locale.zig");
const agent = @import("agent.zig");
const util = @import("util.zig");

pub const Lang = locale.Lang;
pub const Msg = struct { en: []const u8, zh: []const u8 };

pub var lang: Lang = .en;
var ready = false;

pub fn init(allocator: mem.Allocator) void {
    if (ready) return;
    ready = true;
    var env = host.envMap(allocator) catch return;
    defer env.deinit();
    const mac = if (comptime builtin.os.tag == .macos) readMacLanguage(allocator) else null;
    defer if (mac) |owned| allocator.free(owned);
    lang = locale.decide(env.get("NVM_LANG"), env.get("LC_ALL"), env.get("LC_MESSAGES"), env.get("LANG"), mac);
}

pub fn isZh() bool {
    return lang == .zh;
}

pub fn code() []const u8 {
    return if (lang == .zh) "zh" else "en";
}

/// English while `--json` is on, so machine output stays byte-stable.
pub fn useEnglish() bool {
    return agent.json_mode or lang == .en;
}

pub fn t(message: Msg) []const u8 {
    return if (useEnglish()) message.en else message.zh;
}

pub fn out(comptime message: Msg, args: anytype) !void {
    if (useEnglish()) try util.stdout(message.en, args) else try util.stdout(message.zh, args);
}

pub fn err(comptime message: Msg, args: anytype) !void {
    if (useEnglish()) try util.stderr(message.en, args) else try util.stderr(message.zh, args);
}

pub fn format(comptime message: Msg, buf: []u8, args: anytype) []const u8 {
    if (useEnglish()) return std.fmt.bufPrint(buf, message.en, args) catch "error";
    return std.fmt.bufPrint(buf, message.zh, args) catch "error";
}

fn readMacLanguage(allocator: mem.Allocator) ?[]u8 {
    const home = host.getenv("HOME") orelse return null;
    if (home.len == 0) return null;
    const path = fs.path.join(allocator, &.{ home, "Library", "Preferences", ".GlobalPreferences.plist" }) catch return null;
    defer allocator.free(path);
    const file = std.Io.Dir.openFileAbsolute(host.io(), path, .{}) catch return null;
    defer file.close(host.io());
    const data = host.readToEndAlloc(file, allocator, 1024 * 1024) catch return null;
    defer allocator.free(data);
    var buf: [64]u8 = undefined;
    const tag = locale.preferredFromPlist(data, &buf) orelse return null;
    return allocator.dupe(u8, tag) catch null;
}
