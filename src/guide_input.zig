const std = @import("std");
const mem = std.mem;
const select = @import("select.zig");
const i18n = @import("i18n.zig");
const messages = @import("messages.zig");
const util = @import("util.zig");

const stderr = util.stderr;

/// Raw-mode line editor. Esc or empty Enter cancels (`null`). Never returns a lone ESC byte.
pub fn readLine(allocator: mem.Allocator, readByte: *const fn () anyerror!?u8, pollReady: *const fn (i32) anyerror!bool, hint: bool) !?[]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    if (hint) try stderr("{s}\n", .{i18n.t(messages.guide_prompt_hint)});
    try stderr("> ", .{});
    var parser = select.Parser{};
    var pending = select.Keys{};
    while (true) {
        const byte = readByte() catch return null;
        const b = byte orelse {
            if (list.items.len == 0) return null;
            break;
        };
        if (parser.mode != .ground) {
            pending = .{};
            parser.feed(b, &pending);
            while (parser.mode != .ground) {
                if (!try pollReady(100)) {
                    parser.flush(&pending);
                    return null;
                }
                const more = try readByte() orelse {
                    parser.flush(&pending);
                    return null;
                };
                parser.feed(more, &pending);
            }
            if (pending.len > 0) {
                for (pending.slice()) |key| {
                    switch (key) {
                        .back, .eof => return null,
                        .interrupt => return error.GuideInterrupt,
                        else => {},
                    }
                }
            }
            continue;
        }
        switch (b) {
            '\n', '\r' => {
                if (list.items.len == 0) return null;
                break;
            },
            0x1b => {
                parser.feed(b, &pending);
                if (!try pollReady(100)) {
                    parser.flush(&pending);
                    return null;
                }
                continue;
            },
            0x7f, 0x08 => {
                if (list.items.len > 0) _ = list.pop();
            },
            0x15 => {
                list.shrinkRetainingCapacity(0);
            },
            0x03 => return error.GuideInterrupt,
            0x04 => return null,
            else => {
                if (b >= 32 and b < 127) try list.append(allocator, b);
            },
        }
    }
    return try list.toOwnedSlice(allocator);
}
