const std = @import("std");
const mem = std.mem;
const select = @import("select.zig");
const i18n = @import("i18n.zig");
const messages = @import("messages.zig");
const util = @import("util.zig");

const stderr = util.stderr;
const ascii = std.ascii;
const viewport: usize = 12;

pub const Pick = union(enum) { quit, back, index: usize };

pub const Hooks = struct {
    read_key: *const fn () anyerror!?select.Key,
    paint: *const fn (title: []const u8, labels: []const []const u8, back: []const u8, cursor: usize, status: []const u8, up: usize) anyerror!usize,
};

pub const Opts = struct {
    zh: bool,
    title: []const u8,
    initial: usize = 0,
    searchable: bool = false,
};

fn filterChar(b: u8) bool {
    return (b >= '0' and b <= '9') or (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or b == '.' or b == 'v' or b == 'V' or b == '/' or b == '-';
}

fn matches(label: []const u8, query: []const u8) bool {
    if (query.len == 0) return true;
    if (query.len > label.len) return false;
    for (0..label.len - query.len + 1) |i| {
        if (ascii.eqlIgnoreCase(label[i .. i + query.len], query)) return true;
    }
    return false;
}

fn text(zh: bool, en: []const u8, zh_text: []const u8) []const u8 {
    return if (zh) zh_text else en;
}

pub fn pick(labels: []const []const u8, hooks: Hooks, opts: Opts) !Pick {
    std.debug.assert(labels.len > 0);
    var filter: [64]u8 = undefined;
    var filter_len: usize = 0;
    var offset: usize = 0;
    var cursor: usize = @min(opts.initial, labels.len);
    var status: []const u8 = "";
    var painted: usize = 0;
    var indices: [4096]usize = undefined;
    var index_count: usize = 0;

    const rebuild = struct {
        fn f(all: []const []const u8, query: []const u8, out: []usize) usize {
            var n: usize = 0;
            for (all, 0..) |label, i| {
                if (matches(label, query)) {
                    out[n] = i;
                    n += 1;
                }
            }
            return n;
        }
    }.f;

    index_count = rebuild(labels, filter[0..filter_len], &indices);

    const back_label = text(opts.zh, "Back", "返回");

    while (true) {
        index_count = rebuild(labels, filter[0..filter_len], &indices);
        if (index_count == 0 and filter_len > 0) {
            status = i18n.t(messages.guide_no_match);
        } else if (filter_len == 0) {
            status = "";
        }
        if (cursor > index_count) cursor = index_count;
        if (offset + viewport > index_count and index_count > 0) {
            offset = if (index_count > viewport) index_count - viewport else 0;
        }
        if (cursor < offset) offset = cursor;
        if (cursor >= offset + viewport and viewport > 0) offset = cursor - viewport + 1;

        var rows: [viewport + 3][]const u8 = undefined;
        var n: usize = 0;
        if (opts.searchable and filter_len > 0) {
            var buf: [96]u8 = undefined;
            const line = std.fmt.bufPrint(&buf, "Filter: {s}_", .{filter[0..filter_len]}) catch "Filter:";
            rows[n] = line;
            n += 1;
        }
        if (offset > 0 and index_count > 0) {
            rows[n] = text(opts.zh, "... above", "... 上方");
            n += 1;
        }
        const shown = @min(viewport, if (index_count > offset) index_count - offset else 0);
        var i: usize = 0;
        while (i < shown) : (i += 1) {
            rows[n] = labels[indices[offset + i]];
            n += 1;
        }
        if (offset + shown < index_count) {
            var buf: [48]u8 = undefined;
            const more = index_count - offset - shown;
            rows[n] = std.fmt.bufPrint(&buf, "... {d} more", .{more}) catch "... more";
            n += 1;
        }
        const list_len = n;
        painted = try hooks.paint(opts.title, rows[0..list_len], back_label, cursor, status, painted);

        const key = try hooks.read_key() orelse return .quit;
        switch (key) {
            .interrupt => {
                try stderr("{s}\n", .{i18n.t(messages.guide_cancelled)});
                return .quit;
            },
            .eof => return .quit,
            .back, .left => {
                if (opts.searchable and filter_len > 0) {
                    filter_len -= 1;
                    cursor = 0;
                    offset = 0;
                    continue;
                }
                return .back;
            },
            .up => {
                if (cursor == 0) {
                    cursor = index_count;
                } else {
                    cursor -= 1;
                }
            },
            .down => {
                if (cursor >= index_count) {
                    cursor = 0;
                } else {
                    cursor += 1;
                }
            },
            .enter => {
                if (cursor == index_count) return .back;
                if (index_count == 0) continue;
                return .{ .index = indices[cursor] };
            },
            .printable => |byte| {
                if (!opts.searchable) continue;
                if (filterChar(byte) and filter_len < filter.len) {
                    filter[filter_len] = byte;
                    filter_len += 1;
                    cursor = 0;
                    offset = 0;
                }
            },
            .digit => |d| {
                if (opts.searchable) {
                    const byte: u8 = d + '0';
                    if (filter_len < filter.len) {
                        filter[filter_len] = byte;
                        filter_len += 1;
                        cursor = 0;
                        offset = 0;
                    }
                    continue;
                }
                var sel = select.Select.init(list_len + 1);
                sel.cursor = @min(cursor, list_len);
                switch (sel.handle(key)) {
                    .pick => |p| {
                        if (p >= list_len) return .back;
                        if (index_count == 0) continue;
                        return .{ .index = indices[offset + p] };
                    },
                    .back => return .back,
                    .invalid => status = text(opts.zh, "Enter a number from the menu.", "请输入菜单中的编号."),
                    .redraw, .quit => {},
                }
            },
        }
    }
}
