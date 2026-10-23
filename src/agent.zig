const std = @import("std");
const mem = std.mem;
const util = @import("util.zig");
const host = @import("host.zig");

pub var json_mode: bool = false;
pub var yes_mode: bool = false;

pub fn truthy(value: ?[]const u8) bool {
    const raw = mem.trim(u8, value orelse return false, " \t");
    return eqlIgnoreCase(raw, "1") or eqlIgnoreCase(raw, "true") or eqlIgnoreCase(raw, "yes");
}

fn eqlIgnoreCase(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| {
        if (std.ascii.toLower(a) != std.ascii.toLower(b)) return false;
    }
    return true;
}

pub fn forcesNoninteractive(ci: ?[]const u8, flag: ?[]const u8, yes: bool) bool {
    if (yes) return true;
    if (truthy(flag)) return true;
    if (ci) |value| if (mem.trim(u8, value, " \t").len != 0) return true;
    return false;
}

pub fn noninteractive() bool {
    return forcesNoninteractive(host.getenv("CI"), host.getenv("NVM_NONINTERACTIVE"), yes_mode);
}

pub const MenuStream = enum { stdout, stderr };

pub fn menuAllowed(stream: MenuStream) bool {
    if (noninteractive()) return false;
    if (!host.isTty(.stdin())) return false;
    const file: std.Io.File = switch (stream) {
        .stdout => .stdout(),
        .stderr => .stderr(),
    };
    return host.isTty(file);
}

pub const skill_text = @embedFile("../skills/znvm/SKILL.md");

pub fn writeSkill() !void {
    var buf: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(host.io(), &buf);
    try writer.interface.writeAll(skill_text);
    try writer.interface.flush();
}

pub const Flags = struct {
    argv: []const []const u8,
    json: bool,
    yes: bool,
    llm: bool,
};

pub fn strip(allocator: mem.Allocator, args: []const []const u8) !Flags {
    var out: std.ArrayList([]const u8) = .empty;
    errdefer out.deinit(allocator);
    var json = false;
    var yes = false;
    var llm = false;
    var locked = false;
    for (args, 0..) |arg, index| {
        if (!locked and index > 0 and mem.eql(u8, arg, "--")) {
            locked = true;
            try out.append(allocator, arg);
            continue;
        }
        if (!locked and index > 0 and mem.eql(u8, arg, "--json")) {
            json = true;
            continue;
        }
        if (!locked and index > 0 and mem.eql(u8, arg, "--yes")) {
            yes = true;
            continue;
        }
        if (!locked and index > 0 and mem.eql(u8, arg, "--llm")) {
            llm = true;
            continue;
        }
        try out.append(allocator, arg);
    }
    return .{
        .argv = try out.toOwnedSlice(allocator),
        .json = json,
        .yes = yes,
        .llm = llm,
    };
}

fn isOne(value: []const u8, names: []const []const u8) bool {
    for (names) |name| if (mem.eql(u8, value, name)) return true;
    return false;
}

pub fn jsonSupported(invoked_as_nrm: bool, argv: []const []const u8) bool {
    if (argv.len < 2) return false;
    const cmd = argv[1];
    if (invoked_as_nrm) {
        if (isOne(cmd, &.{ "ls", "list", "current", "test", "--version", "-v" })) return true;
        return mem.eql(u8, cmd, "scope") and argv.len >= 3 and isOne(argv[2], &.{ "ls", "list" });
    }
    if (isOne(cmd, &.{ "ls", "list", "ls-remote", "list-remote", "current", "which", "version", "--version", "-v" })) return true;
    return mem.eql(u8, cmd, "mirror") and argv.len >= 3 and isOne(argv[2], &.{ "ls", "list", "test" });
}

pub fn fail(code: u8, message: []const u8) noreturn {
    if (json_mode) {
        var buf: [2048]u8 = undefined;
        const body = formatError(&buf, code, message) catch "{\"error\":\"failed\",\"exit\":1}";
        util.stderr("{s}\n", .{body}) catch {};
    } else {
        util.stderr("{s}\n", .{message}) catch {};
    }
    std.process.exit(code);
}

pub fn explain(message: []const u8) error{Explained} {
    if (json_mode) fail(1, message);
    util.stderr("{s}\n", .{message}) catch {};
    return error.Explained;
}

fn formatError(buf: []u8, code: u8, message: []const u8) ![]u8 {
    var writer: std.Io.Writer = .fixed(buf);
    try writer.writeAll("{\"error\":");
    try writeQuoted(&writer, message);
    try writer.writeAll(",\"exit\":");
    try writer.print("{d}", .{code});
    try writer.writeAll("}");
    return writer.buffered();
}

fn writeQuoted(writer: *std.Io.Writer, text: []const u8) !void {
    try writer.writeByte('"');
    for (text) |char| switch (char) {
        '"' => try writer.writeAll("\\\""),
        '\\' => try writer.writeAll("\\\\"),
        '\n' => try writer.writeAll("\\n"),
        '\r' => try writer.writeAll("\\r"),
        '\t' => try writer.writeAll("\\t"),
        else => if (char < 0x20) {
            try writeHex4(writer, char);
        } else try writer.writeByte(char),
    };
    try writer.writeByte('"');
}

pub const Sink = struct {
    allocator: mem.Allocator,
    buf: std.ArrayList(u8) = .empty,
    started: std.ArrayList(bool) = .empty,
    expect_value: bool = false,

    pub fn init(allocator: mem.Allocator) Sink {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Sink) void {
        self.buf.deinit(self.allocator);
        self.started.deinit(self.allocator);
    }

    fn sep(self: *Sink) !void {
        if (self.expect_value) {
            self.expect_value = false;
            return;
        }
        if (self.started.items.len == 0) return;
        const index = self.started.items.len - 1;
        if (self.started.items[index]) try self.buf.append(self.allocator, ',');
        self.started.items[index] = true;
    }

    pub fn beginObject(self: *Sink) !void {
        try self.sep();
        try self.buf.append(self.allocator, '{');
        try self.started.append(self.allocator, false);
    }

    pub fn endObject(self: *Sink) !void {
        _ = self.started.pop();
        try self.buf.append(self.allocator, '}');
    }

    pub fn beginArray(self: *Sink) !void {
        try self.sep();
        try self.buf.append(self.allocator, '[');
        try self.started.append(self.allocator, false);
    }

    pub fn endArray(self: *Sink) !void {
        _ = self.started.pop();
        try self.buf.append(self.allocator, ']');
    }

    pub fn key(self: *Sink, name: []const u8) !void {
        try self.sep();
        try self.buf.append(self.allocator, '"');
        try appendEscaped(&self.buf, self.allocator, name);
        try self.buf.appendSlice(self.allocator, "\":");
        self.expect_value = true;
    }

    pub fn string(self: *Sink, value: []const u8) !void {
        try self.sep();
        try self.buf.append(self.allocator, '"');
        try appendEscaped(&self.buf, self.allocator, value);
        try self.buf.append(self.allocator, '"');
    }

    pub fn nullValue(self: *Sink) !void {
        try self.sep();
        try self.buf.appendSlice(self.allocator, "null");
    }

    pub fn boolean(self: *Sink, value: bool) !void {
        try self.sep();
        try self.buf.appendSlice(self.allocator, if (value) "true" else "false");
    }

    pub fn fieldString(self: *Sink, name: []const u8, value: []const u8) !void {
        try self.key(name);
        try self.string(value);
    }

    pub fn fieldNull(self: *Sink, name: []const u8) !void {
        try self.key(name);
        try self.nullValue();
    }

    pub fn fieldBool(self: *Sink, name: []const u8, value: bool) !void {
        try self.key(name);
        try self.boolean(value);
    }

    pub fn flush(self: *Sink) !void {
        try util.stdout("{s}\n", .{self.buf.items});
    }
};

fn writeHex4(writer: anytype, char: u8) !void {
    const hex = "0123456789abcdef";
    try writer.writeAll("\\u00");
    try writer.writeByte(hex[char >> 4]);
    try writer.writeByte(hex[char & 0xf]);
}

fn appendHex4(buf: *std.ArrayList(u8), allocator: mem.Allocator, char: u8) !void {
    const hex = "0123456789abcdef";
    try buf.appendSlice(allocator, "\\u00");
    try buf.append(allocator, hex[char >> 4]);
    try buf.append(allocator, hex[char & 0xf]);
}

fn appendEscaped(buf: *std.ArrayList(u8), allocator: mem.Allocator, text: []const u8) !void {
    for (text) |char| switch (char) {
        '"' => try buf.appendSlice(allocator, "\\\""),
        '\\' => try buf.appendSlice(allocator, "\\\\"),
        '\n' => try buf.appendSlice(allocator, "\\n"),
        '\r' => try buf.appendSlice(allocator, "\\r"),
        '\t' => try buf.appendSlice(allocator, "\\t"),
        else => if (char < 0x20) {
            try appendHex4(buf, allocator, char);
        } else try buf.append(allocator, char),
    };
}

test "noninteractive flags" {
    try std.testing.expect(!forcesNoninteractive(null, null, false));
    try std.testing.expect(!forcesNoninteractive("", "0", false));
    try std.testing.expect(forcesNoninteractive("true", null, false));
    try std.testing.expect(forcesNoninteractive(null, "Yes", false));
    try std.testing.expect(forcesNoninteractive(null, null, true));
}

test "strip keeps positionals and a double dash" {
    const allocator = std.testing.allocator;
    const flags = try strip(allocator, &.{ "nvm", "--json", "exec", "20", "--", "--yes" });
    defer allocator.free(flags.argv);
    try std.testing.expect(flags.json);
    try std.testing.expect(!flags.yes);
    try std.testing.expect(!flags.llm);
    try std.testing.expectEqualSlices(u8, "exec", flags.argv[1]);
    try std.testing.expectEqualSlices(u8, "--yes", flags.argv[4]);
}

test "json object escapes strings" {
    const allocator = std.testing.allocator;
    var sink = Sink.init(allocator);
    defer sink.deinit();
    try sink.beginObject();
    try sink.fieldString("error", "say \"hi\"\n");
    try sink.fieldNull("url");
    try sink.fieldBool("ok", false);
    try sink.key("versions");
    try sink.beginArray();
    try sink.beginObject();
    try sink.fieldString("version", "v1");
    try sink.endObject();
    try sink.endArray();
    try sink.endObject();
    try std.testing.expectEqualStrings("{\"error\":\"say \\\"hi\\\"\\n\",\"url\":null,\"ok\":false,\"versions\":[{\"version\":\"v1\"}]}", sink.buf.items);
}
