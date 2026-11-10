const std = @import("std");

pub const GUIDE_AT_PREFIX = "__nvm_guide_at=";

pub const At = struct {
    root_cursor: usize = 0,
    menu: usize = 0,
    item: usize = 0,
    cursor: usize = 0,
};

pub fn parseAt(raw: ?[]const u8) At {
    const s = raw orelse return .{};
    if (s.len == 0) return .{};
    var parts: [4]usize = .{ 0, 0, 0, 0 };
    var idx: usize = 0;
    var start: usize = 0;
    for (s, 0..) |c, i| {
        if (c == ':') {
            if (idx < 4) {
                parts[idx] = std.fmt.parseInt(usize, s[start..i], 10) catch 0;
                idx += 1;
            }
            start = i + 1;
        }
    }
    if (idx < 4) parts[idx] = std.fmt.parseInt(usize, s[start..], 10) catch 0;
    return .{
        .root_cursor = parts[0],
        .menu = parts[1],
        .item = parts[2],
        .cursor = parts[3],
    };
}

pub fn formatAt(buf: []u8, at: At) []const u8 {
    return std.fmt.bufPrint(buf, "{d}:{d}:{d}:{d}", .{ at.root_cursor, at.menu, at.item, at.cursor }) catch "0:0:0:0";
}
