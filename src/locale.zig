const std = @import("std");
const mem = std.mem;

pub const Lang = enum { en, zh };

/// `NVM_LANG=zh|en` wins. Otherwise the first non-empty of LC_ALL, LC_MESSAGES, LANG.
/// `zh*` is Chinese. `C`, `POSIX`, `C.UTF-8`, and `en*` are neutral and, on macOS,
/// defer to `mac` (the first AppleLanguages entry, else AppleLocale). Any other
/// locale is English. `mac` is null off macOS.
pub fn decide(nvm_lang: ?[]const u8, lc_all: ?[]const u8, lc_messages: ?[]const u8, lang: ?[]const u8, mac: ?[]const u8) Lang {
    if (nvm_lang) |raw| {
        const value = mem.trim(u8, raw, " \t");
        if (mem.eql(u8, value, "zh")) return .zh;
        if (mem.eql(u8, value, "en")) return .en;
    }
    const values = [_]?[]const u8{ lc_all, lc_messages, lang };
    for (values) |maybe| {
        const value = maybe orelse continue;
        if (value.len == 0) continue;
        if (mem.startsWith(u8, value, "zh")) return .zh;
        if (isNeutral(value)) return fromMac(mac);
        return .en;
    }
    return fromMac(mac);
}

fn isNeutral(value: []const u8) bool {
    if (mem.eql(u8, value, "C") or mem.eql(u8, value, "POSIX")) return true;
    if (mem.eql(u8, value, "C.UTF-8") or mem.eql(u8, value, "C.utf8")) return true;
    return mem.startsWith(u8, value, "en");
}

fn fromMac(mac: ?[]const u8) Lang {
    const value = mac orelse return .en;
    if (mem.startsWith(u8, value, "zh")) return .zh;
    return .en;
}

/// First preferred language tag from a binary or XML GlobalPreferences plist.
/// Copies into `out`. Checks AppleLanguages, then AppleLocale.
pub fn preferredFromPlist(data: []const u8, out: []u8) ?[]const u8 {
    if (mem.startsWith(u8, data, "bplist00")) return fromBinary(data, out);
    if (mem.indexOf(u8, data, "<plist") != null or mem.startsWith(u8, data, "<?xml")) return fromXml(data, out);
    return null;
}

fn fromXml(data: []const u8, out: []u8) ?[]const u8 {
    if (stringAfterKey(data, "AppleLanguages")) |tag| return copyTag(tag, out);
    if (stringAfterKey(data, "AppleLocale")) |tag| return copyTag(tag, out);
    return null;
}

fn stringAfterKey(data: []const u8, key: []const u8) ?[]const u8 {
    var needle_buf: [64]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "<key>{s}</key>", .{key}) catch return null;
    const at = mem.indexOf(u8, data, needle) orelse return null;
    const rest = data[at + needle.len ..];
    const open = mem.indexOf(u8, rest, "<string>") orelse return null;
    const body = rest[open + "<string>".len ..];
    const end = mem.indexOf(u8, body, "</string>") orelse return null;
    if (end == 0) return null;
    return body[0..end];
}

fn fromBinary(data: []const u8, out: []u8) ?[]const u8 {
    if (data.len < 40) return null;
    const trailer = data[data.len - 32 ..];
    const offset_size: usize = trailer[6];
    const ref_size: usize = trailer[7];
    if (offset_size == 0 or offset_size > 8 or ref_size == 0 or ref_size > 8) return null;
    const num_objects = readBE(trailer, 8, 8) orelse return null;
    const top = readBE(trailer, 16, 8) orelse return null;
    const table = readBE(trailer, 24, 8) orelse return null;
    if (top >= num_objects) return null;
    const ctx = Ctx{
        .data = data,
        .offset_size = offset_size,
        .ref_size = ref_size,
        .table = table,
        .num_objects = num_objects,
    };
    const root = ctx.objectOffset(top) orelse return null;
    if (dictString(ctx, root, "AppleLanguages", out)) |tag| return tag;
    return dictString(ctx, root, "AppleLocale", out);
}

const Ctx = struct {
    data: []const u8,
    offset_size: usize,
    ref_size: usize,
    table: u64,
    num_objects: u64,

    fn objectOffset(self: Ctx, index: u64) ?usize {
        if (index >= self.num_objects) return null;
        const at = self.table + index * self.offset_size;
        const off = readBE(self.data, @intCast(at), self.offset_size) orelse return null;
        if (off >= self.data.len) return null;
        return @intCast(off);
    }
};

fn dictString(ctx: Ctx, offset: usize, key: []const u8, out: []u8) ?[]const u8 {
    var pos = offset;
    const marker = ctx.data[pos];
    if (marker >> 4 != 0xD) {
        // AppleLanguages may be the direct value when the root is not a dict of that key.
        return null;
    }
    const count = objectCount(ctx.data, &pos) orelse return null;
    const refs_at = pos;
    const ref_bytes = count * ctx.ref_size;
    if (refs_at + ref_bytes * 2 > ctx.data.len) return null;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const key_index = readBE(ctx.data, refs_at + i * ctx.ref_size, ctx.ref_size) orelse return null;
        const key_off = ctx.objectOffset(key_index) orelse return null;
        var key_buf: [64]u8 = undefined;
        const found = readString(ctx, key_off, &key_buf) orelse continue;
        if (!mem.eql(u8, found, key)) continue;
        const val_index = readBE(ctx.data, refs_at + ref_bytes + i * ctx.ref_size, ctx.ref_size) orelse return null;
        const val_off = ctx.objectOffset(val_index) orelse return null;
        return readLangValue(ctx, val_off, out);
    }
    return null;
}

fn readLangValue(ctx: Ctx, offset: usize, out: []u8) ?[]const u8 {
    const marker = ctx.data[offset];
    if (marker >> 4 == 0x5 or marker >> 4 == 0x6) {
        return readString(ctx, offset, out);
    }
    if (marker >> 4 != 0xA) return null;
    var pos = offset;
    const count = objectCount(ctx.data, &pos) orelse return null;
    if (count == 0) return null;
    const first = readBE(ctx.data, pos, ctx.ref_size) orelse return null;
    const off = ctx.objectOffset(first) orelse return null;
    return readString(ctx, off, out);
}

fn readString(ctx: Ctx, offset: usize, out: []u8) ?[]const u8 {
    var pos = offset;
    if (pos >= ctx.data.len) return null;
    const marker = ctx.data[pos];
    const kind = marker >> 4;
    if (kind != 0x5 and kind != 0x6) return null;
    const count = objectCount(ctx.data, &pos) orelse return null;
    if (kind == 0x5) {
        if (pos + count > ctx.data.len or count > out.len) return null;
        @memcpy(out[0..count], ctx.data[pos .. pos + count]);
        return out[0..count];
    }
    if (pos + count * 2 > ctx.data.len or count > out.len) return null;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const hi = ctx.data[pos + i * 2];
        const lo = ctx.data[pos + i * 2 + 1];
        if (hi != 0 or lo > 127) return null;
        out[i] = lo;
    }
    return out[0..count];
}

/// Advances `pos` past the marker and the optional extended length. Returns the count.
fn objectCount(data: []const u8, pos: *usize) ?usize {
    if (pos.* >= data.len) return null;
    const marker = data[pos.*];
    pos.* += 1;
    const len: usize = marker & 0x0F;
    if (len != 15) return len;
    if (pos.* >= data.len) return null;
    const int_marker = data[pos.*];
    pos.* += 1;
    if (int_marker >> 4 != 0x1) return null;
    const int_len: usize = @as(usize, 1) << @intCast(int_marker & 0x0F);
    const n = readBE(data, pos.*, int_len) orelse return null;
    pos.* += int_len;
    return @intCast(n);
}

fn readBE(data: []const u8, at: usize, size: usize) ?u64 {
    if (size == 0 or size > 8 or at + size > data.len) return null;
    var value: u64 = 0;
    for (data[at .. at + size]) |byte| value = (value << 8) | byte;
    return value;
}

fn copyTag(tag: []const u8, out: []u8) ?[]const u8 {
    if (tag.len == 0 or tag.len > out.len) return null;
    @memcpy(out[0..tag.len], tag);
    return out[0..tag.len];
}
