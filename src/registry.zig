const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;
const process = std.process;

const util = @import("util.zig");

const stdout = util.stdout;
const stderr = util.stderr;

pub const china_registry = "https://registry.npmmirror.com";
pub const official_registry = "https://registry.npmjs.org";

pub const Scope = struct {
    name: []u8,
    url: []u8,
};

const Named = struct {
    name: []u8,
    url: []u8,
};

const Builtin = struct {
    name: []const u8,
    url: []const u8,
};

const builtin_registries = [_]Builtin{
    .{ .name = "npm", .url = "https://registry.npmjs.org/" },
    .{ .name = "yarn", .url = "https://registry.yarnpkg.com/" },
    .{ .name = "tencent", .url = "https://mirrors.tencent.com/npm/" },
    .{ .name = "cnpm", .url = "https://r.cnpmjs.org/" },
    .{ .name = "taobao", .url = "https://registry.npmmirror.com/" },
    .{ .name = "npmMirror", .url = "https://skimdb.npmjs.com/registry/" },
    .{ .name = "huawei", .url = "https://repo.huaweicloud.com/repository/npm/" },
};

pub const Map = struct {
    default_url: ?[]u8 = null,
    current_name: ?[]u8 = null,
    names: std.ArrayList(Named) = .{},
    scopes: std.ArrayList(Scope) = .{},

    pub fn deinit(self: *Map, allocator: mem.Allocator) void {
        if (self.default_url) |url| allocator.free(url);
        if (self.current_name) |name| allocator.free(name);
        for (self.names.items) |named| {
            allocator.free(named.name);
            allocator.free(named.url);
        }
        self.names.deinit(allocator);
        for (self.scopes.items) |scope| {
            allocator.free(scope.name);
            allocator.free(scope.url);
        }
        self.scopes.deinit(allocator);
    }

    pub fn sort(self: *Map) void {
        mem.sort(Scope, self.scopes.items, {}, scopeLess);
    }

    fn upsert(self: *Map, allocator: mem.Allocator, name: []const u8, url: []const u8) !void {
        for (self.scopes.items) |*scope| {
            if (mem.eql(u8, scope.name, name)) {
                const next = try allocator.dupe(u8, url);
                allocator.free(scope.url);
                scope.url = next;
                return;
            }
        }
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_url = try allocator.dupe(u8, url);
        errdefer allocator.free(owned_url);
        try self.scopes.append(allocator, .{ .name = owned_name, .url = owned_url });
        self.sort();
    }

    fn remove(self: *Map, allocator: mem.Allocator, name: []const u8) bool {
        for (self.scopes.items, 0..) |scope, i| {
            if (!mem.eql(u8, scope.name, name)) continue;
            allocator.free(scope.name);
            allocator.free(scope.url);
            _ = self.scopes.orderedRemove(i);
            return true;
        }
        return false;
    }

    fn setDefault(self: *Map, allocator: mem.Allocator, url: []const u8) !void {
        const next = try allocator.dupe(u8, url);
        errdefer allocator.free(next);
        if (self.default_url) |old| allocator.free(old);
        self.default_url = next;
        try self.assignCurrent(allocator, self.lookupName(url));
    }

    fn assignCurrent(self: *Map, allocator: mem.Allocator, name: ?[]const u8) !void {
        const next = if (name) |value| try allocator.dupe(u8, value) else null;
        errdefer if (next) |value| allocator.free(value);
        if (self.current_name) |old| allocator.free(old);
        self.current_name = next;
    }

    fn lookupName(self: *const Map, url: []const u8) ?[]const u8 {
        for (builtin_registries) |item| {
            if (sameUrl(item.url, url)) return item.name;
        }
        for (self.names.items) |item| {
            if (sameUrl(item.url, url)) return item.name;
        }
        return null;
    }

    fn urlForName(self: *const Map, name: []const u8) ?[]const u8 {
        if (findBuiltin(name)) |item| return item.url;
        for (self.names.items) |item| {
            if (mem.eql(u8, item.name, name)) return item.url;
        }
        return null;
    }

    fn upsertName(self: *Map, allocator: mem.Allocator, name: []const u8, url: []const u8) !void {
        for (self.names.items) |*named| {
            if (mem.eql(u8, named.name, name)) {
                const next = try allocator.dupe(u8, url);
                allocator.free(named.url);
                named.url = next;
                return;
            }
        }
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_url = try allocator.dupe(u8, url);
        errdefer allocator.free(owned_url);
        try self.names.append(allocator, .{ .name = owned_name, .url = owned_url });
        self.sortNames();
    }

    fn removeName(self: *Map, allocator: mem.Allocator, name: []const u8) bool {
        for (self.names.items, 0..) |named, i| {
            if (!mem.eql(u8, named.name, name)) continue;
            allocator.free(named.name);
            allocator.free(named.url);
            _ = self.names.orderedRemove(i);
            return true;
        }
        return false;
    }

    fn sortNames(self: *Map) void {
        mem.sort(Named, self.names.items, {}, nameLess);
    }

    fn isCurrent(self: *const Map, name: []const u8, url: []const u8) bool {
        if (self.current_name) |active| return mem.eql(u8, active, name);
        if (self.default_url) |default| return sameUrl(default, url);
        return false;
    }
};

pub fn printError(err: anyerror) !void {
    switch (err) {
        error.InvalidScope => try stderr("error: Scope must look like @company.\n", .{}),
        error.InvalidUrl => try stderr("error: Registry must be an http:// or https:// URL.\n", .{}),
        error.ScopeMissing => try stderr("error: That scope is not in the map.\n", .{}),
        error.NoHome => try stderr("error: HOME is not set.\n", .{}),
        error.NoMap => try stderr("error: No registry map yet. Set a default or a scope first.\n", .{}),
        error.InvalidName => try stderr("error: registry name must be letters, digits, '-', '_', or '.'.\n", .{}),
        error.CurlMissing => try stderr("error: curl is required for nrm test.\n", .{}),
        error.Explained => {},
        else => try stderr("error: registry failed: {s}\n", .{@errorName(err)}),
    }
}

pub fn show(allocator: mem.Allocator, root: []const u8) !void {
    var env = try openEnv(allocator);
    defer env.deinit();
    const store = try storePath(allocator, root);
    defer allocator.free(store);
    var loaded = load(allocator, root) catch |err| switch (err) {
        error.NoMap => null,
        else => return err,
    };
    if (loaded) |*map| {
        defer map.deinit(allocator);
        try printMap(map);
    } else {
        try stderr("No registry map in {s}\n", .{store});
    }
    try printTargets(allocator, env);
}

pub fn add(allocator: mem.Allocator, root: []const u8, scope: []const u8, url: []const u8) !void {
    const name = try normalizeScope(scope);
    const registry_url = try normalizeUrl(url);
    var map = try loadOrEmpty(allocator, root);
    errdefer map.deinit(allocator);
    try map.upsert(allocator, name, registry_url);
    try save(allocator, root, &map);
    try syncMap(allocator, root, &map);
    map.deinit(allocator);
}

pub fn removeScope(allocator: mem.Allocator, root: []const u8, scope: []const u8) !void {
    const name = try normalizeScope(scope);
    var map = try load(allocator, root);
    errdefer map.deinit(allocator);
    if (!map.remove(allocator, name)) return error.ScopeMissing;
    try save(allocator, root, &map);
    try syncMap(allocator, root, &map);
    map.deinit(allocator);
}

pub fn setDefault(allocator: mem.Allocator, root: []const u8, url: []const u8) !void {
    const registry_url = try normalizeUrl(url);
    var map = try loadOrEmpty(allocator, root);
    errdefer map.deinit(allocator);
    try map.setDefault(allocator, registry_url);
    try save(allocator, root, &map);
    try syncMap(allocator, root, &map);
    map.deinit(allocator);
}

pub fn useChina(allocator: mem.Allocator, root: []const u8) !void {
    try setDefault(allocator, root, china_registry);
}

pub fn useOfficial(allocator: mem.Allocator, root: []const u8) !void {
    try setDefault(allocator, root, official_registry);
}

pub fn sync(allocator: mem.Allocator, root: []const u8) !void {
    var map = try load(allocator, root);
    defer map.deinit(allocator);
    try syncMap(allocator, root, &map);
}

pub fn listNames(allocator: mem.Allocator, root: []const u8) !void {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    for (builtin_registries) |item| try printNameLine(&map, item.name, item.url);
    for (map.names.items) |item| try printNameLine(&map, item.name, item.url);
}

pub fn current(allocator: mem.Allocator, root: []const u8, show_url: bool) !void {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    if (show_url) {
        if (map.default_url) |url| try stdout("{s}\n", .{url}) else try stdout("none\n", .{});
        return;
    }
    if (map.current_name) |name| {
        try stdout("{s}\n", .{name});
        return;
    }
    if (map.default_url) |url| {
        if (map.lookupName(url)) |name| try stdout("{s}\n", .{name}) else try stdout("{s}\n", .{url});
        return;
    }
    try stdout("none\n", .{});
}

pub fn useName(allocator: mem.Allocator, root: []const u8, raw_name: []const u8) !void {
    const name = try normalizeName(raw_name);
    var map = try loadOrEmpty(allocator, root);
    errdefer map.deinit(allocator);
    const found = map.urlForName(name) orelse {
        try stderr("error: {s} is not a registry.\n", .{name});
        return error.Explained;
    };
    const url = try allocator.dupe(u8, found);
    defer allocator.free(url);
    try map.setDefault(allocator, url);
    try map.assignCurrent(allocator, name);
    try save(allocator, root, &map);
    try stdout("The registry has been changed to '{s}'.\n", .{name});
    try syncMap(allocator, root, &map);
    map.deinit(allocator);
}

pub fn addName(allocator: mem.Allocator, root: []const u8, raw_name: []const u8, raw_url: []const u8) !void {
    const name = try normalizeName(raw_name);
    if (mem.eql(u8, name, "auto")) {
        try stderr("error: auto is reserved.\n", .{});
        return error.Explained;
    }
    if (findBuiltin(name) != null) {
        try stderr("error: {s} is a built-in registry.\n", .{name});
        return error.Explained;
    }
    const url = try normalizeUrl(raw_url);
    var map = try loadOrEmpty(allocator, root);
    errdefer map.deinit(allocator);
    try map.upsertName(allocator, name, url);
    try save(allocator, root, &map);
    try stdout("added {s}\n", .{name});
    map.deinit(allocator);
}

pub fn delName(allocator: mem.Allocator, root: []const u8, raw_name: []const u8) !void {
    const name = try normalizeName(raw_name);
    if (findBuiltin(name) != null) {
        try stderr("error: {s} is a built-in registry.\n", .{name});
        return error.Explained;
    }
    var map = try load(allocator, root);
    errdefer map.deinit(allocator);
    if (!map.removeName(allocator, name)) {
        try stderr("error: {s} is not a registry.\n", .{name});
        return error.Explained;
    }
    if (map.current_name) |active| {
        if (mem.eql(u8, active, name)) {
            const inferred = if (map.default_url) |url| map.lookupName(url) else null;
            try map.assignCurrent(allocator, inferred);
        }
    }
    try save(allocator, root, &map);
    try stdout("deleted {s}\n", .{name});
    map.deinit(allocator);
}

pub fn listScopes(allocator: mem.Allocator, root: []const u8) !void {
    var loaded = load(allocator, root) catch |err| switch (err) {
        error.NoMap => null,
        else => return err,
    };
    if (loaded) |*map| {
        defer map.deinit(allocator);
        if (map.scopes.items.len == 0) {
            try stdout("No scopes.\n", .{});
            return;
        }
        for (map.scopes.items) |scope| try stdout("{s} {s}\n", .{ scope.name, scope.url });
        return;
    }
    try stdout("No scopes.\n", .{});
}

pub fn testRegistries(allocator: mem.Allocator, root: []const u8, only: ?[]const u8) !void {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    var entries: std.ArrayList(Named) = .{};
    defer {
        for (entries.items) |item| {
            allocator.free(item.name);
            allocator.free(item.url);
        }
        entries.deinit(allocator);
    }
    if (only) |raw| {
        const name = try normalizeName(raw);
        const found = map.urlForName(name) orelse {
            try stderr("error: {s} is not a registry.\n", .{name});
            return error.Explained;
        };
        try entries.append(allocator, .{
            .name = try allocator.dupe(u8, name),
            .url = try allocator.dupe(u8, found),
        });
    } else {
        for (builtin_registries) |item| {
            try entries.append(allocator, .{
                .name = try allocator.dupe(u8, item.name),
                .url = try allocator.dupe(u8, item.url),
            });
        }
        for (map.names.items) |item| {
            try entries.append(allocator, .{
                .name = try allocator.dupe(u8, item.name),
                .url = try allocator.dupe(u8, item.url),
            });
        }
    }
    const samples = try measureEntries(allocator, entries.items);
    defer allocator.free(samples);
    for (entries.items, samples) |item, sample| try printProbe(item.name, sample);
    if (only == null) try rememberRegistries(allocator, root, entries.items, samples);
}

pub fn useAuto(allocator: mem.Allocator, root: []const u8) !void {
    const binary = @import("binary.zig");
    var entries = try collectEntries(allocator, root, null);
    defer freeEntries(allocator, &entries);
    const names = try allocator.alloc([]const u8, entries.items.len);
    defer allocator.free(names);
    for (entries.items, 0..) |item, i| names[i] = item.name;
    if (try binary.cachedRegistries(allocator, root, names)) |hits| {
        defer {
            for (hits) |*hit| hit.deinit(allocator);
            allocator.free(hits);
        }
        const winner = fastestName(entries.items, hits) orelse {
            try stderr("error: no registry responded.\n", .{});
            return error.Explained;
        };
        return useName(allocator, root, winner);
    }
    const samples = try measureEntries(allocator, entries.items);
    defer allocator.free(samples);
    try rememberRegistries(allocator, root, entries.items, samples);
    const winner = fastestSample(entries.items, samples) orelse {
        try stderr("error: no registry responded.\n", .{});
        return error.Explained;
    };
    return useName(allocator, root, winner);
}

fn collectEntries(allocator: mem.Allocator, root: []const u8, only: ?[]const u8) !std.ArrayList(Named) {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    var entries: std.ArrayList(Named) = .{};
    errdefer freeEntries(allocator, &entries);
    if (only) |raw| {
        const name = try normalizeName(raw);
        const found = map.urlForName(name) orelse {
            try stderr("error: {s} is not a registry.\n", .{name});
            return error.Explained;
        };
        try entries.append(allocator, .{
            .name = try allocator.dupe(u8, name),
            .url = try allocator.dupe(u8, found),
        });
        return entries;
    }
    for (builtin_registries) |item| {
        try entries.append(allocator, .{
            .name = try allocator.dupe(u8, item.name),
            .url = try allocator.dupe(u8, item.url),
        });
    }
    for (map.names.items) |item| {
        try entries.append(allocator, .{
            .name = try allocator.dupe(u8, item.name),
            .url = try allocator.dupe(u8, item.url),
        });
    }
    return entries;
}

fn freeEntries(allocator: mem.Allocator, entries: *std.ArrayList(Named)) void {
    for (entries.items) |item| {
        allocator.free(item.name);
        allocator.free(item.url);
    }
    entries.deinit(allocator);
}

fn measureEntries(allocator: mem.Allocator, entries: []const Named) ![]@import("binary.zig").Sample {
    const binary = @import("binary.zig");
    const urls = try allocator.alloc([]const u8, entries.len);
    defer allocator.free(urls);
    for (entries, 0..) |item, i| urls[i] = item.url;
    return binary.probeParallel(allocator, urls);
}

fn rememberRegistries(allocator: mem.Allocator, root: []const u8, entries: []const Named, samples: []const @import("binary.zig").Sample) !void {
    const binary = @import("binary.zig");
    const rows = try allocator.alloc(binary.Row, entries.len);
    defer allocator.free(rows);
    for (entries, 0..) |item, i| {
        rows[i] = .{ .name = item.name, .ok = samples[i].ok, .seconds = samples[i].seconds() };
    }
    try binary.storeRegistries(allocator, root, rows);
}

fn printProbe(name: []const u8, sample: @import("binary.zig").Sample) !void {
    if (!sample.ok) {
        try stdout("{s} error\n", .{name});
        return;
    }
    try stdout("{s} {s}s\n", .{ name, sample.seconds() });
}

fn fastestName(entries: []const Named, hits: []const @import("binary.zig").Hit) ?[]const u8 {
    var best: ?usize = null;
    var best_time: f64 = 0;
    for (entries, hits, 0..) |item, hit, i| {
        if (!hit.ok) continue;
        const time = std.fmt.parseFloat(f64, hit.seconds) catch continue;
        if (best == null or time < best_time) {
            best = i;
            best_time = time;
            _ = item;
        }
    }
    if (best) |index| return entries[index].name;
    return null;
}

fn fastestSample(entries: []const Named, samples: []const @import("binary.zig").Sample) ?[]const u8 {
    var best: ?usize = null;
    var best_time: f64 = 0;
    for (entries, samples, 0..) |_, sample, i| {
        if (!sample.ok) continue;
        const time = std.fmt.parseFloat(f64, sample.seconds()) catch continue;
        if (best == null or time < best_time) {
            best = i;
            best_time = time;
        }
    }
    if (best) |index| return entries[index].name;
    return null;
}

fn printNameLine(map: *const Map, name: []const u8, url: []const u8) !void {
    if (map.isCurrent(name, url)) {
        try stdout("* {s} {s}\n", .{ name, url });
    } else {
        try stdout("  {s} {s}\n", .{ name, url });
    }
}

pub fn renderNpmrc(allocator: mem.Allocator, existing: []const u8, map: *const Map) ![]u8 {
    var out: std.ArrayList(u8) = .{};
    errdefer out.deinit(allocator);
    try appendKept(allocator, &out, existing, map, managedNpm);
    if (map.default_url) |url| try appendLine(allocator, &out, "registry={s}", .{url});
    for (map.scopes.items) |scope| {
        try appendLine(allocator, &out, "{s}:registry={s}", .{ scope.name, scope.url });
    }
    return out.toOwnedSlice(allocator);
}

pub fn renderYarnrc(allocator: mem.Allocator, existing: []const u8, map: *const Map) ![]u8 {
    var out: std.ArrayList(u8) = .{};
    errdefer out.deinit(allocator);
    try appendKept(allocator, &out, existing, map, managedYarn);
    if (map.default_url) |url| {
        const quoted = try quote(allocator, url);
        defer allocator.free(quoted);
        try appendLine(allocator, &out, "registry {s}", .{quoted});
    }
    for (map.scopes.items) |scope| {
        const key = try std.fmt.allocPrint(allocator, "{s}:registry", .{scope.name});
        defer allocator.free(key);
        const quoted_key = try quote(allocator, key);
        defer allocator.free(quoted_key);
        const quoted_url = try quote(allocator, scope.url);
        defer allocator.free(quoted_url);
        try appendLine(allocator, &out, "{s} {s}", .{ quoted_key, quoted_url });
    }
    return out.toOwnedSlice(allocator);
}

pub fn renderYarnYml(allocator: mem.Allocator, existing: []const u8, map: *const Map) ![]u8 {
    var out: std.ArrayList(u8) = .{};
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < existing.len) {
        const next = mem.indexOfScalarPos(u8, existing, i, '\n') orelse existing.len;
        const line = trimCr(existing[i..next]);
        i = if (next == existing.len) existing.len else next + 1;
        const trimmed = mem.trim(u8, line, " \t");
        if (mem.eql(u8, trimmed, "# znvm registry begin")) {
            while (i < existing.len) {
                const end_rel = mem.indexOfScalarPos(u8, existing, i, '\n') orelse existing.len;
                const end_line = trimCr(existing[i..end_rel]);
                i = if (end_rel == existing.len) existing.len else end_rel + 1;
                if (mem.eql(u8, mem.trim(u8, end_line, " \t"), "# znvm registry end")) break;
            }
            continue;
        }
        if (map.default_url != null and !indented(line) and mem.startsWith(u8, trimmed, "npmRegistryServer:")) continue;
        if (!indented(line) and mem.startsWith(u8, trimmed, "npmScopes:")) {
            while (i < existing.len) {
                const look = mem.indexOfScalarPos(u8, existing, i, '\n') orelse existing.len;
                const follow = trimCr(existing[i..look]);
                if (!(follow.len == 0 or indented(follow))) break;
                i = if (look == existing.len) existing.len else look + 1;
            }
            continue;
        }
        try out.appendSlice(allocator, line);
        try out.append(allocator, '\n');
    }
    const write_block = map.default_url != null or map.scopes.items.len > 0;
    if (write_block) {
        try out.appendSlice(allocator, "# znvm registry begin\n");
        if (map.default_url) |url| {
            const quoted = try quote(allocator, url);
            defer allocator.free(quoted);
            try appendLine(allocator, &out, "npmRegistryServer: {s}", .{quoted});
        }
        if (map.scopes.items.len > 0) {
            try out.appendSlice(allocator, "npmScopes:\n");
            for (map.scopes.items) |scope| {
                const quoted = try quote(allocator, scope.url);
                defer allocator.free(quoted);
                try appendLine(allocator, &out, "  {s}:", .{bareScope(scope.name)});
                try appendLine(allocator, &out, "    npmRegistryServer: {s}", .{quoted});
            }
        }
        try out.appendSlice(allocator, "# znvm registry end\n");
    }
    return out.toOwnedSlice(allocator);
}

pub fn renderBunfig(allocator: mem.Allocator, existing: []const u8, map: *const Map) ![]u8 {
    var out: std.ArrayList(u8) = .{};
    errdefer out.deinit(allocator);
    var i: usize = 0;
    var section: []const u8 = "";
    var seen_install = false;
    var wrote_registry = map.default_url == null;
    while (i < existing.len) {
        const next = mem.indexOfScalarPos(u8, existing, i, '\n') orelse existing.len;
        const line = trimCr(existing[i..next]);
        i = if (next == existing.len) existing.len else next + 1;
        const header = sectionHeader(line);
        if (header) |name| {
            if (mem.eql(u8, section, "install") and map.default_url != null and !wrote_registry) {
                const quoted = try quote(allocator, map.default_url.?);
                defer allocator.free(quoted);
                try appendLine(allocator, &out, "registry = {s}", .{quoted});
                wrote_registry = true;
            }
            section = name;
            if (mem.eql(u8, name, "install.scopes")) {
                while (i < existing.len) {
                    const look = mem.indexOfScalarPos(u8, existing, i, '\n') orelse existing.len;
                    if (sectionHeader(trimCr(existing[i..look])) != null) break;
                    i = if (look == existing.len) existing.len else look + 1;
                }
                continue;
            }
            if (mem.eql(u8, name, "install")) seen_install = true;
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
            continue;
        }
        if (mem.eql(u8, section, "install") and map.default_url != null and isTomlRegistry(line)) {
            const quoted = try quote(allocator, map.default_url.?);
            defer allocator.free(quoted);
            try appendLine(allocator, &out, "registry = {s}", .{quoted});
            wrote_registry = true;
            continue;
        }
        try out.appendSlice(allocator, line);
        try out.append(allocator, '\n');
    }
    if (mem.eql(u8, section, "install") and map.default_url != null and !wrote_registry) {
        const quoted = try quote(allocator, map.default_url.?);
        defer allocator.free(quoted);
        try appendLine(allocator, &out, "registry = {s}", .{quoted});
        wrote_registry = true;
    }
    if (map.default_url != null and !seen_install) {
        if (out.items.len > 0 and out.items[out.items.len - 1] != '\n') try out.append(allocator, '\n');
        try out.appendSlice(allocator, "[install]\n");
        const quoted = try quote(allocator, map.default_url.?);
        defer allocator.free(quoted);
        try appendLine(allocator, &out, "registry = {s}", .{quoted});
    }
    if (map.scopes.items.len > 0) {
        try out.appendSlice(allocator, "[install.scopes]\n");
        for (map.scopes.items) |scope| {
            const quoted = try quote(allocator, scope.url);
            defer allocator.free(quoted);
            const key = try tomlKey(allocator, scope.name);
            defer allocator.free(key);
            try appendLine(allocator, &out, "{s} = {s}", .{ key, quoted });
        }
    }
    return out.toOwnedSlice(allocator);
}

fn syncMap(allocator: mem.Allocator, root: []const u8, map: *Map) !void {
    var env = try openEnv(allocator);
    defer env.deinit();
    map.sort();
    const files = try targetPaths(allocator, env);
    defer files.deinit(allocator);
    try rewrite(allocator, files.npmrc, map, renderNpmrc);
    try rewrite(allocator, files.yarnrc, map, renderYarnrc);
    try rewrite(allocator, files.yarnrc_yml, map, renderYarnYml);
    try rewrite(allocator, files.pnpmrc, map, renderNpmrc);
    try rewrite(allocator, files.bunfig, map, renderBunfig);
    try printMap(map);
    try stderr("Wrote {s}\n", .{files.npmrc});
    try stderr("Wrote {s}\n", .{files.yarnrc});
    try stderr("Wrote {s}\n", .{files.yarnrc_yml});
    try stderr("Wrote {s}\n", .{files.pnpmrc});
    try stderr("Wrote {s}\n", .{files.bunfig});
    _ = root;
}

fn rewrite(
    allocator: mem.Allocator,
    path: []const u8,
    map: *Map,
    render: *const fn (mem.Allocator, []const u8, *const Map) anyerror![]u8,
) !void {
    const existing = try readOptional(allocator, path);
    defer allocator.free(existing);
    const body = try render(allocator, existing, map);
    try writeRendered(allocator, path, body);
}

fn writeRendered(allocator: mem.Allocator, path: []const u8, body: []u8) !void {
    defer allocator.free(body);
    try ensureParent(path);
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(body);
}

fn readOptional(allocator: mem.Allocator, path: []const u8) ![]u8 {
    const file = fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return allocator.dupe(u8, ""),
        else => return err,
    };
    defer file.close();
    return file.readToEndAlloc(allocator, 1024 * 1024);
}

const Files = struct {
    npmrc: []u8,
    yarnrc: []u8,
    yarnrc_yml: []u8,
    pnpmrc: []u8,
    bunfig: []u8,

    fn deinit(self: Files, allocator: mem.Allocator) void {
        allocator.free(self.npmrc);
        allocator.free(self.yarnrc);
        allocator.free(self.yarnrc_yml);
        allocator.free(self.pnpmrc);
        allocator.free(self.bunfig);
    }
};

fn targetPaths(allocator: mem.Allocator, env: Env) !Files {
    const pnpmrc = if (env.xdg) |xdg|
        try fs.path.join(allocator, &.{ xdg, "pnpm", "rc" })
    else if (builtin.os.tag == .macos)
        try fs.path.join(allocator, &.{ env.home, "Library", "Preferences", "pnpm", "rc" })
    else
        try fs.path.join(allocator, &.{ env.home, ".config", "pnpm", "rc" });
    return .{
        .npmrc = try fs.path.join(allocator, &.{ env.home, ".npmrc" }),
        .yarnrc = try fs.path.join(allocator, &.{ env.home, ".yarnrc" }),
        .yarnrc_yml = try fs.path.join(allocator, &.{ env.home, ".yarnrc.yml" }),
        .pnpmrc = pnpmrc,
        .bunfig = try fs.path.join(allocator, &.{ env.home, ".bunfig.toml" }),
    };
}

fn printTargets(allocator: mem.Allocator, env: Env) !void {
    const files = try targetPaths(allocator, env);
    defer files.deinit(allocator);
    try stderr("Sync writes:\n  {s}\n  {s}\n  {s}\n  {s}\n  {s}\n", .{
        files.npmrc,
        files.yarnrc,
        files.yarnrc_yml,
        files.pnpmrc,
        files.bunfig,
    });
}

fn printMap(map: *const Map) !void {
    if (map.default_url) |url| {
        try stderr("default {s}\n", .{url});
    } else {
        try stderr("default (not set)\n", .{});
    }
    for (map.scopes.items) |scope| try stderr("{s} {s}\n", .{ scope.name, scope.url });
}

fn storePath(allocator: mem.Allocator, root: []const u8) ![]u8 {
    return fs.path.join(allocator, &.{ root, "registries.json" });
}

fn loadOrEmpty(allocator: mem.Allocator, root: []const u8) !Map {
    return load(allocator, root) catch |err| switch (err) {
        error.NoMap => return .{},
        else => return err,
    };
}

fn load(allocator: mem.Allocator, root: []const u8) !Map {
    const path = try storePath(allocator, root);
    defer allocator.free(path);
    const body = readOptional(allocator, path) catch |err| return err;
    defer allocator.free(body);
    if (body.len == 0) return error.NoMap;
    const StoredScope = struct { name: []const u8, registry: []const u8 };
    const StoredName = struct { name: []const u8, registry: []const u8 };
    const Stored = struct {
        default: ?[]const u8 = null,
        current: ?[]const u8 = null,
        names: []const StoredName = &.{},
        scopes: []const StoredScope = &.{},
    };
    const parsed = try std.json.parseFromSlice(Stored, allocator, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    defer parsed.deinit();
    var map = Map{};
    errdefer map.deinit(allocator);
    if (parsed.value.default) |url| {
        _ = try normalizeUrl(url);
        map.default_url = try allocator.dupe(u8, url);
    }
    for (parsed.value.names) |named| {
        const name = normalizeName(named.name) catch continue;
        if (findBuiltin(name) != null) continue;
        const url = try normalizeUrl(named.registry);
        try map.upsertName(allocator, name, url);
    }
    for (parsed.value.scopes) |scope| {
        const name = try normalizeScope(scope.name);
        const url = try normalizeUrl(scope.registry);
        try map.upsert(allocator, name, url);
    }
    if (parsed.value.current) |name| {
        if (normalizeName(name)) |ok| {
            if (map.urlForName(ok) != null) try map.assignCurrent(allocator, ok);
        } else |_| {}
    } else if (map.default_url) |url| {
        try map.assignCurrent(allocator, map.lookupName(url));
    }
    return map;
}

fn save(allocator: mem.Allocator, root: []const u8, map: *Map) !void {
    try ensureParent(root);
    var root_dir = try fs.openDirAbsolute("/", .{});
    defer root_dir.close();
    const rel_root = if (root.len > 0 and root[0] == '/') root[1..] else root;
    try root_dir.makePath(rel_root);
    map.sort();
    map.sortNames();
    var body: std.ArrayList(u8) = .{};
    defer body.deinit(allocator);
    try body.appendSlice(allocator, "{\n  \"default\": ");
    if (map.default_url) |url| {
        const quoted = try quote(allocator, url);
        defer allocator.free(quoted);
        try body.appendSlice(allocator, quoted);
    } else {
        try body.appendSlice(allocator, "null");
    }
    try body.appendSlice(allocator, ",\n  \"current\": ");
    if (map.current_name) |name| {
        const quoted = try quote(allocator, name);
        defer allocator.free(quoted);
        try body.appendSlice(allocator, quoted);
    } else {
        try body.appendSlice(allocator, "null");
    }
    try body.appendSlice(allocator, ",\n  \"names\": [\n");
    for (map.names.items, 0..) |named, i| {
        const name = try quote(allocator, named.name);
        defer allocator.free(name);
        const url = try quote(allocator, named.url);
        defer allocator.free(url);
        const comma: []const u8 = if (i + 1 == map.names.items.len) "" else ",";
        const line = try std.fmt.allocPrint(allocator, "    {{\"name\": {s}, \"registry\": {s}}}{s}\n", .{ name, url, comma });
        defer allocator.free(line);
        try body.appendSlice(allocator, line);
    }
    try body.appendSlice(allocator, "  ],\n  \"scopes\": [\n");
    for (map.scopes.items, 0..) |scope, i| {
        const name = try quote(allocator, scope.name);
        defer allocator.free(name);
        const url = try quote(allocator, scope.url);
        defer allocator.free(url);
        const comma: []const u8 = if (i + 1 == map.scopes.items.len) "" else ",";
        const line = try std.fmt.allocPrint(allocator, "    {{\"name\": {s}, \"registry\": {s}}}{s}\n", .{ name, url, comma });
        defer allocator.free(line);
        try body.appendSlice(allocator, line);
    }
    try body.appendSlice(allocator, "  ]\n}\n");
    const path = try storePath(allocator, root);
    defer allocator.free(path);
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(body.items);
}

const Env = struct {
    map: process.EnvMap,
    home: []const u8,
    xdg: ?[]const u8,

    fn deinit(self: *Env) void {
        self.map.deinit();
    }
};

fn openEnv(allocator: mem.Allocator) !Env {
    var env_map = try process.getEnvMap(allocator);
    errdefer env_map.deinit();
    const home = env_map.get("HOME") orelse return error.NoHome;
    if (home.len == 0 or !fs.path.isAbsolute(home)) return error.NoHome;
    const xdg = env_map.get("XDG_CONFIG_HOME");
    const xdg_abs = if (xdg) |value| (if (value.len > 0 and fs.path.isAbsolute(value)) value else null) else null;
    return .{ .map = env_map, .home = home, .xdg = xdg_abs };
}

fn ensureParent(path: []const u8) !void {
    const parent = fs.path.dirname(path) orelse return;
    var root = try fs.openDirAbsolute("/", .{});
    defer root.close();
    const rel = if (parent.len > 0 and parent[0] == '/') parent[1..] else parent;
    if (rel.len == 0) return;
    try root.makePath(rel);
}

fn appendKept(
    allocator: mem.Allocator,
    out: *std.ArrayList(u8),
    existing: []const u8,
    map: *const Map,
    drop: *const fn ([]const u8, *const Map) bool,
) !void {
    var i: usize = 0;
    while (i < existing.len) {
        const next = mem.indexOfScalarPos(u8, existing, i, '\n') orelse existing.len;
        const line = trimCr(existing[i..next]);
        i = if (next == existing.len) existing.len else next + 1;
        if (drop(line, map)) continue;
        try out.appendSlice(allocator, line);
        try out.append(allocator, '\n');
    }
}

fn managedNpm(line: []const u8, map: *const Map) bool {
    const key = npmKey(line) orelse return false;
    if (mem.eql(u8, key, "registry")) return map.default_url != null;
    return mem.startsWith(u8, key, "@") and mem.endsWith(u8, key, ":registry");
}

fn managedYarn(line: []const u8, map: *const Map) bool {
    const trimmed = mem.trim(u8, line, " \t");
    if (trimmed.len == 0 or trimmed[0] == '#') return false;
    if (map.default_url != null and (mem.eql(u8, trimmed, "registry") or mem.startsWith(u8, trimmed, "registry ") or mem.startsWith(u8, trimmed, "registry\t"))) return true;
    if (mem.indexOf(u8, trimmed, ":registry") == null) return false;
    return mem.startsWith(u8, trimmed, "\"@") or mem.startsWith(u8, trimmed, "@");
}

fn npmKey(line: []const u8) ?[]const u8 {
    const trimmed = mem.trim(u8, line, " \t");
    if (trimmed.len == 0 or trimmed[0] == '#' or trimmed[0] == ';') return null;
    const eq = mem.indexOfScalar(u8, trimmed, '=') orelse return null;
    return mem.trim(u8, trimmed[0..eq], " \t");
}

fn appendLine(allocator: mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) !void {
    const line = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(line);
    try out.appendSlice(allocator, line);
    try out.append(allocator, '\n');
}

fn quote(allocator: mem.Allocator, text: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .{};
    errdefer out.deinit(allocator);
    try out.append(allocator, '"');
    for (text) |char| {
        if (char == '\\' or char == '"') try out.append(allocator, '\\');
        try out.append(allocator, char);
    }
    try out.append(allocator, '"');
    return out.toOwnedSlice(allocator);
}

fn bareScope(name: []const u8) []const u8 {
    if (name.len > 0 and name[0] == '@') return name[1..];
    return name;
}

fn tomlKey(allocator: mem.Allocator, name: []const u8) ![]u8 {
    const bare = bareScope(name);
    for (bare) |char| {
        const ok = std.ascii.isAlphanumeric(char) or char == '-' or char == '_';
        if (!ok) return quote(allocator, bare);
    }
    return allocator.dupe(u8, bare);
}

fn indented(line: []const u8) bool {
    return line.len > 0 and (line[0] == ' ' or line[0] == '\t');
}

fn trimCr(line: []const u8) []const u8 {
    if (line.len > 0 and line[line.len - 1] == '\r') return line[0 .. line.len - 1];
    return line;
}

fn sectionHeader(line: []const u8) ?[]const u8 {
    const trimmed = mem.trim(u8, line, " \t");
    if (trimmed.len < 3 or trimmed[0] != '[' or trimmed[trimmed.len - 1] != ']') return null;
    if (mem.indexOfScalar(u8, trimmed, '#') != null) return null;
    return mem.trim(u8, trimmed[1 .. trimmed.len - 1], " \t");
}

fn isTomlRegistry(line: []const u8) bool {
    const trimmed = mem.trim(u8, line, " \t");
    if (!mem.startsWith(u8, trimmed, "registry")) return false;
    const rest = mem.trim(u8, trimmed["registry".len..], " \t");
    return rest.len > 0 and rest[0] == '=';
}

fn scopeLess(_: void, a: Scope, b: Scope) bool {
    return mem.lessThan(u8, a.name, b.name);
}

fn nameLess(_: void, a: Named, b: Named) bool {
    return mem.lessThan(u8, a.name, b.name);
}

pub fn normalizeScope(raw: []const u8) ![]const u8 {
    const name = mem.trim(u8, raw, " \t");
    if (name.len < 2 or name.len > 128 or name[0] != '@') return error.InvalidScope;
    if (mem.indexOfScalar(u8, name, '/') != null) return error.InvalidScope;
    for (name[1..]) |char| {
        const ok = std.ascii.isAlphanumeric(char) or char == '-' or char == '_' or char == '.';
        if (!ok) return error.InvalidScope;
    }
    return name;
}

fn normalizeName(raw: []const u8) ![]const u8 {
    const name = mem.trim(u8, raw, " \t");
    if (name.len < 1 or name.len > 64) return error.InvalidName;
    if (name[0] == '@' or mem.indexOfScalar(u8, name, '/') != null) return error.InvalidName;
    for (name) |char| {
        const ok = std.ascii.isAlphanumeric(char) or char == '-' or char == '_' or char == '.';
        if (!ok) return error.InvalidName;
    }
    return name;
}

fn findBuiltin(name: []const u8) ?Builtin {
    for (builtin_registries) |item| {
        if (mem.eql(u8, item.name, name)) return item;
    }
    return null;
}

fn sameUrl(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, stripOneSlash(a), stripOneSlash(b));
}

fn stripOneSlash(url: []const u8) []const u8 {
    if (url.len > 1 and url[url.len - 1] == '/') return url[0 .. url.len - 1];
    return url;
}

pub fn normalizeUrl(raw: []const u8) ![]const u8 {
    const url = mem.trim(u8, raw, " \t");
    if (url.len < 8 or url.len > 400) return error.InvalidUrl;
    const https = mem.startsWith(u8, url, "https://");
    const http = mem.startsWith(u8, url, "http://");
    if (!https and !http) return error.InvalidUrl;
    if (mem.indexOfAny(u8, url, " \t\r\n\"'`") != null) return error.InvalidUrl;
    return url;
}

fn expectHas(haystack: []const u8, needle: []const u8) !void {
    if (mem.indexOf(u8, haystack, needle) == null) return error.TestExpectedEqual;
}

fn expectMissing(haystack: []const u8, needle: []const u8) !void {
    if (mem.indexOf(u8, haystack, needle) != null) return error.TestExpectedEqual;
}

test "registry files keep unrelated lines and scope routes" {
    const allocator = std.testing.allocator;
    var map = Map{};
    defer map.deinit(allocator);
    try map.upsert(allocator, "@company", "https://npm.company.example");
    try map.upsert(allocator, "@acme", "https://npm.acme.example");

    const npmrc = try renderNpmrc(allocator,
        \\prefix=/tmp/npm
        \\registry=https://keep.example
        \\@old:registry=https://old.example
        \\//registry.npmjs.org/:_authToken=secret
        \\fund=false
        \\# nvm binaries begin
        \\electron_mirror=https://cdn.npmmirror.com/binaries/electron/
        \\# nvm binaries end
        \\
    , &map);
    defer allocator.free(npmrc);
    try expectHas(npmrc, "prefix=/tmp/npm\n");
    try expectHas(npmrc, "registry=https://keep.example\n");
    try expectHas(npmrc, "//registry.npmjs.org/:_authToken=secret\n");
    try expectHas(npmrc, "fund=false\n");
    try expectHas(npmrc, "# nvm binaries begin\n");
    try expectHas(npmrc, "electron_mirror=https://cdn.npmmirror.com/binaries/electron/\n");
    try expectHas(npmrc, "@acme:registry=https://npm.acme.example\n");
    try expectHas(npmrc, "@company:registry=https://npm.company.example\n");
    try expectMissing(npmrc, "@old:registry");

    try map.setDefault(allocator, china_registry);
    const replaced = try renderNpmrc(allocator, npmrc, &map);
    defer allocator.free(replaced);
    try expectHas(replaced, "registry=" ++ china_registry ++ "\n");
    try expectMissing(replaced, "keep.example");
    try expectHas(replaced, "_authToken=secret");
    try expectHas(replaced, "# nvm binaries begin\n");
    try expectHas(replaced, "electron_mirror=https://cdn.npmmirror.com/binaries/electron/\n");
    try expectHas(replaced, "@company:registry=https://npm.company.example\n");

    const yarn = try renderYarnrc(allocator, "save-prefix \"~\"\nregistry \"https://old.example\"\n", &map);
    defer allocator.free(yarn);
    try expectHas(yarn, "save-prefix \"~\"\n");
    try expectHas(yarn, "registry \"" ++ china_registry ++ "\"\n");
    try expectHas(yarn, "\"@company:registry\" \"https://npm.company.example\"\n");

    const yml = try renderYarnYml(allocator,
        \\nodeLinker: node-modules
        \\npmRegistryServer: "https://old.example"
        \\npmScopes:
        \\  old:
        \\    npmRegistryServer: "https://old.example"
        \\    npmAuthToken: "secret"
        \\enableGlobalCache: true
        \\
    , &map);
    defer allocator.free(yml);
    try expectHas(yml, "nodeLinker: node-modules\n");
    try expectHas(yml, "enableGlobalCache: true\n");
    try expectMissing(yml, "npmAuthToken");
    try expectMissing(yml, "old.example");
    try expectHas(yml, "npmRegistryServer: \"" ++ china_registry ++ "\"\n");
    try expectHas(yml, "  company:\n    npmRegistryServer: \"https://npm.company.example\"\n");

    const bun = try renderBunfig(allocator,
        \\[install]
        \\cache = true
        \\registry = "https://old.example"
        \\
        \\[install.scopes]
        \\old = "https://old.example"
        \\
        \\[run]
        \\silent = true
        \\
    , &map);
    defer allocator.free(bun);
    try expectHas(bun, "cache = true\n");
    try expectHas(bun, "registry = \"" ++ china_registry ++ "\"\n");
    try expectHas(bun, "[run]\nsilent = true\n");
    try expectHas(bun, "[install.scopes]\n");
    try expectHas(bun, "acme = \"https://npm.acme.example\"\n");
    try expectMissing(bun, "old = ");

    try std.testing.expectError(error.InvalidScope, normalizeScope("company"));
    try std.testing.expectError(error.InvalidScope, normalizeScope("@a/b"));
    try std.testing.expectError(error.InvalidUrl, normalizeUrl("ftp://example.com"));
    try std.testing.expect(sameUrl(china_registry, "https://registry.npmmirror.com/"));
    try std.testing.expect(sameUrl(official_registry, "https://registry.npmjs.org/"));
    try std.testing.expect(!sameUrl(china_registry, official_registry));
    try std.testing.expect(findBuiltin("taobao") != null);
    try std.testing.expect(findBuiltin("local") == null);
    try std.testing.expectError(error.InvalidName, normalizeName("@company"));
    try std.testing.expectError(error.InvalidName, normalizeName("a/b"));
}
