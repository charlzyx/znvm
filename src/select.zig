const std = @import("std");
const mem = std.mem;
const testing = std.testing;

pub const Key = union(enum) {
    up,
    down,
    left,
    enter,
    back,
    interrupt,
    digit: u8,

};

pub const Result = union(enum) {
    redraw,
    invalid,
    pick: usize,
    back,
    quit,
};

pub const Select = struct {
    count: usize,
    cursor: usize,
    digits: [4]u8 = undefined,
    digit_len: u8 = 0,

    pub fn init(count: usize) Select {
        return .{ .count = count, .cursor = 0 };
    }

    pub fn handle(self: *Select, key: Key) Result {
        switch (key) {
            .up => {
                self.clearDigits();
                self.move(true);
                return .redraw;
            },
            .down => {
                self.clearDigits();
                self.move(false);
                return .redraw;
            },
            .left, .back => {
                self.clearDigits();
                return .back;
            },
            .interrupt => return .quit,
            .enter => return self.commit(),
            .digit => |d| return self.pushDigit(d),
        }
    }

    fn clearDigits(self: *Select) void {
        self.digit_len = 0;
    }

    fn rows(self: Select) usize {
        return self.count + 1;
    }

    fn move(self: *Select, up: bool) void {
        const n = self.rows();
        if (n == 0) return;
        if (up) {
            self.cursor = if (self.cursor == 0) n - 1 else self.cursor - 1;
        } else {
            self.cursor = (self.cursor + 1) % n;
        }
    }

    fn pushDigit(self: *Select, d: u8) Result {
        if (self.digit_len >= self.digits.len) {
            self.clearDigits();
            return .invalid;
        }
        self.digits[self.digit_len] = d;
        self.digit_len += 1;
        const n = self.number() orelse {
            self.clearDigits();
            return .invalid;
        };
        if (n == 0) self.cursor = self.count;
        if (n >= 1 and n <= self.count) self.cursor = n - 1;
        return .redraw;
    }

    fn number(self: Select) ?usize {
        if (self.digit_len == 0) return null;
        var n: usize = 0;
        for (self.digits[0..self.digit_len]) |d| {
            n = std.math.mul(usize, n, 10) catch return null;
            n = std.math.add(usize, n, d) catch return null;
        }
        return n;
    }

    fn commit(self: *Select) Result {
        if (self.digit_len == 0) {
            if (self.cursor == self.count) return .back;
            return .{ .pick = self.cursor };
        }
        const n = self.number() orelse {
            self.clearDigits();
            return .invalid;
        };
        self.clearDigits();
        if (n == 0) return .back;
        if (n > self.count) return .invalid;
        return .{ .pick = n - 1 };
    }
};

const Mode = enum { ground, esc, csi, ss3 };

pub const Parser = struct {
    mode: Mode = .ground,

    pub fn feed(self: *Parser, byte: u8, out: *Keys) void {
        switch (self.mode) {
            .ground => self.ground(byte, out),
            .esc => self.escape(byte, out),
            .csi => self.csi(byte, out),
            .ss3 => self.arrow(byte, out),
        }
    }

    pub fn flush(self: *Parser, out: *Keys) void {
        if (self.mode == .esc) out.push(.back);
        self.mode = .ground;
    }

    fn ground(self: *Parser, byte: u8, out: *Keys) void {
        switch (byte) {
            0x03 => out.push(.interrupt),
            0x1b => self.mode = .esc,
            '\r', '\n' => out.push(.enter),
            'q', 'Q' => out.push(.back),
            'k', 'K' => out.push(.up),
            'j', 'J' => out.push(.down),
            '0'...'9' => out.push(.{ .digit = byte - '0' }),
            else => {},
        }
    }

    fn escape(self: *Parser, byte: u8, out: *Keys) void {
        switch (byte) {
            '[' => self.mode = .csi,
            'O' => self.mode = .ss3,
            else => {
                self.mode = .ground;
                out.push(.back);
                self.ground(byte, out);
            },
        }
    }

    fn csi(self: *Parser, byte: u8, out: *Keys) void {
        if (byte >= '0' and byte <= '9' or byte == ';') return;
        self.arrow(byte, out);
    }

    fn arrow(self: *Parser, byte: u8, out: *Keys) void {
        self.mode = .ground;
        switch (byte) {
            'A' => out.push(.up),
            'B' => out.push(.down),
            'D' => out.push(.left),
            else => {},
        }
    }
};

pub const Keys = struct {
    items: [16]Key = undefined,
    len: usize = 0,

    pub fn push(self: *Keys, key: Key) void {
        if (self.len >= self.items.len) return;
        self.items[self.len] = key;
        self.len += 1;
    }

    pub fn slice(self: *const Keys) []const Key {
        return self.items[0..self.len];
    }
};

pub fn parseKeys(bytes: []const u8, flush: bool) Keys {
    var parser = Parser{};
    var out = Keys{};
    for (bytes) |byte| parser.feed(byte, &out);
    if (flush) parser.flush(&out);
    return out;
}

pub fn colorEnabled(no_color: ?[]const u8, term: ?[]const u8) bool {
    if (no_color) |raw| {
        if (mem.trim(u8, raw, " \t").len != 0) return false;
    }
    if (term) |raw| {
        if (mem.eql(u8, raw, "dumb")) return false;
    }
    return true;
}

pub const Frame = struct {
    title: []const u8,
    labels: []const []const u8,
    back: []const u8,
    cursor: usize,
    color: bool,
    status: []const u8,
    up: usize,
};

pub fn frameLines(item_count: usize) usize {
    return item_count + 5;
}

pub fn writeFrame(w: *std.Io.Writer, frame: Frame) !usize {
    const lines = frameLines(frame.labels.len);
    if (frame.up > 0) try w.print("\x1b[{d}A", .{frame.up});
    const clear: []const u8 = if (frame.up > 0) "\x1b[2K" else "";
    const width: usize = if (frame.labels.len >= 10) 2 else 1;
    try writeLine(w, clear, "", false, false);
    try writeLine(w, clear, frame.title, false, false);
    try writeLine(w, clear, "", false, false);
    for (frame.labels, 0..) |label, i| {
        try writeRow(w, clear, frame.cursor == i, frame.color, width, i + 1, label);
    }
    try writeRow(w, clear, frame.cursor == frame.labels.len, frame.color, width, 0, frame.back);
    try writeLine(w, clear, frame.status, false, false);
    return lines;
}

fn writeLine(w: *std.Io.Writer, clear: []const u8, text: []const u8, selected: bool, color: bool) !void {
    try w.writeAll(clear);
    if (selected and color) try w.writeAll("\x1b[1;7m");
    try w.writeAll(text);
    if (selected and color) try w.writeAll("\x1b[0m");
    try w.writeAll("\n");
}

fn writeRow(w: *std.Io.Writer, clear: []const u8, selected: bool, color: bool, width: usize, num: usize, label: []const u8) !void {
    try w.writeAll(clear);
    if (selected and color) try w.writeAll("\x1b[1;7m");
    const marker: []const u8 = if (selected) "> " else "  ";
    if (width >= 2) {
        try w.print("{s}{d: >2}  {s}", .{ marker, num, label });
    } else {
        try w.print("{s}{d}  {s}", .{ marker, num, label });
    }
    if (selected and color) try w.writeAll("\x1b[0m");
    try w.writeAll("\n");
}

fn expectKeys(bytes: []const u8, flush: bool, expected: []const Key) !void {
    const got = parseKeys(bytes, flush);
    try testing.expectEqual(expected.len, got.len);
    for (expected, got.slice()) |want, have| try testing.expect(std.meta.eql(want, have));
}

fn apply(sel: *Select, bytes: []const u8) Result {
    const keys = parseKeys(bytes, true);
    var last: Result = .redraw;
    for (keys.slice()) |key| last = sel.handle(key);
    return last;
}

test "arrow bytes, vim keys, esc, and ctrl-c" {
    try expectKeys("\x1b[A", false, &.{.up});
    try expectKeys("\x1b[B", false, &.{.down});
    try expectKeys("\x1b[D", false, &.{.left});
    try expectKeys("\x1b[C", false, &.{});
    try expectKeys("\x1bOA", false, &.{.up});
    try expectKeys("\x1bOB", false, &.{.down});
    try expectKeys("\x1bOD", false, &.{.left});
    try expectKeys("\x1b[1;5A", false, &.{.up});
    try expectKeys("kj", false, &.{ .up, .down });
    try expectKeys("qQ", false, &.{ .back, .back });
    try expectKeys("\x1b", true, &.{.back});
    try expectKeys("\x1b", false, &.{});
    try expectKeys("\x1bq", false, &.{ .back, .back });
    try expectKeys("\r\n", false, &.{ .enter, .enter });
    try expectKeys("\x03", false, &.{.interrupt});
    try expectKeys("4", false, &.{.{ .digit = 4 }});
    try expectKeys("10", false, &.{ .{ .digit = 1 }, .{ .digit = 0 } });
    try expectKeys("x", false, &.{});
}

test "highlight moves, wraps, and enter confirms the row" {
    var sel = Select.init(3);
    try testing.expect(apply(&sel, "\x1b[B") == .redraw);
    try testing.expectEqual(@as(usize, 1), sel.cursor);
    try testing.expectEqual(@as(usize, 1), apply(&sel, "\r").pick);
    sel = Select.init(3);
    try testing.expect(apply(&sel, "j") == .redraw);
    try testing.expect(apply(&sel, "j") == .redraw);
    try testing.expect(apply(&sel, "j") == .redraw);
    try testing.expectEqual(@as(usize, 3), sel.cursor);
    try testing.expect(apply(&sel, "\n") == .back);
    sel = Select.init(2);
    try testing.expect(apply(&sel, "k") == .redraw);
    try testing.expectEqual(sel.count, sel.cursor);
    try testing.expect(apply(&sel, "\r") == .back);
    sel = Select.init(2);
    try testing.expectEqual(@as(usize, 0), apply(&sel, "\r").pick);
}

test "number then enter still picks, including 0 and a two-digit row" {
    var sel = Select.init(10);
    try testing.expectEqual(@as(usize, 3), apply(&sel, "4\n").pick);
    sel = Select.init(10);
    try testing.expectEqual(@as(usize, 9), apply(&sel, "10\r").pick);
    sel = Select.init(10);
    try testing.expectEqual(@as(usize, 0), apply(&sel, "1\n").pick);
    sel = Select.init(10);
    _ = apply(&sel, "1");
    try testing.expectEqual(@as(usize, 0), sel.cursor);
    try testing.expect(apply(&sel, "\n").pick == 0);
    sel = Select.init(10);
    try testing.expect(apply(&sel, "0\n") == .back);
    sel = Select.init(3);
    try testing.expect(apply(&sel, "9\n") == .invalid);
    try testing.expectEqual(@as(u8, 0), sel.digit_len);
    sel = Select.init(10);
    _ = apply(&sel, "4");
    try testing.expect(apply(&sel, "k") == .redraw);
    try testing.expectEqual(@as(u8, 0), sel.digit_len);
}

test "esc, q, left, and ctrl-c" {
    var sel = Select.init(4);
    try testing.expect(apply(&sel, "\x1b") == .back);
    sel = Select.init(4);
    try testing.expect(apply(&sel, "q") == .back);
    sel = Select.init(4);
    try testing.expect(apply(&sel, "\x1b[D") == .back);
    sel = Select.init(4);
    try testing.expect(apply(&sel, "\x03") == .quit);
    _ = apply(&sel, "j");
    try testing.expect(apply(&sel, "Q") == .back);
}

test "plain marker, and reverse only when color is allowed" {
    try testing.expect(colorEnabled(null, null));
    try testing.expect(colorEnabled("", "xterm"));
    try testing.expect(colorEnabled("   ", null));
    try testing.expect(!colorEnabled("1", null));
    try testing.expect(!colorEnabled("true", "xterm-256color"));
    try testing.expect(!colorEnabled(null, "dumb"));

    const labels = [_][]const u8{ "One", "Two" };
    var storage: [1024]u8 = undefined;
    var plain = std.Io.Writer.fixed(&storage);
    const lines = try writeFrame(&plain, .{
        .title = "Title",
        .labels = &labels,
        .back = "Back",
        .cursor = 1,
        .color = false,
        .status = "",
        .up = 0,
    });
    try testing.expectEqual(frameLines(2), lines);
    try testing.expectEqualStrings(
        \\
        \\Title
        \\
        \\  1  One
        \\> 2  Two
        \\  0  Back
        \\
        \\
    , storage[0..plain.end]);
    try testing.expect(mem.indexOf(u8, storage[0..plain.end], "\x1b") == null);

    var colored_buf: [1024]u8 = undefined;
    var colored = std.Io.Writer.fixed(&colored_buf);
    _ = try writeFrame(&colored, .{
        .title = "Title",
        .labels = &labels,
        .back = "Back",
        .cursor = 0,
        .color = true,
        .status = "bad",
        .up = lines,
    });
    const painted = colored_buf[0..colored.end];
    try testing.expect(mem.startsWith(u8, painted, "\x1b[7A"));
    try testing.expect(mem.indexOf(u8, painted, "\x1b[1;7m> 1  One\x1b[0m") != null);
    try testing.expect(mem.indexOf(u8, painted, "\x1b[1;7m  2") == null);
    try testing.expect(mem.indexOf(u8, painted, "bad\n") != null);

    const wide = [_][]const u8{ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" };
    var wide_buf: [2048]u8 = undefined;
    var wide_w = std.Io.Writer.fixed(&wide_buf);
    _ = try writeFrame(&wide_w, .{
        .title = "Wide",
        .labels = &wide,
        .back = "Exit",
        .cursor = 9,
        .color = false,
        .status = "",
        .up = 0,
    });
    const wide_text = wide_buf[0..wide_w.end];
    try testing.expect(mem.indexOf(u8, wide_text, "> 10  j\n") != null);
    try testing.expect(mem.indexOf(u8, wide_text, "  0  Exit\n") != null);
}
