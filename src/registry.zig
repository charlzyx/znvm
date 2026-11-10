const std = @import("std");
const host = @import("host.zig");
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;
const process = std.process;

const util = @import("util.zig");
const agent = @import("agent.zig");
const i18n = @import("i18n.zig");
const messages = @import("messages.zig");

const stdout = util.stdout;
const stderr = util.stderr;

fn report(message: []const u8) !void {
    if (agent.json_mode) agent.fail(1, message);
    try stderr("{s}\n", .{message});
}

pub const china_registry = "https://registry.npmmirror.com";
pub const official_registry = "https://registry.npmjs.org";

pub const Scope = struct {
    name: []u8,
    url: []u8,
};

const Named = struct {
    name: []u8,
    url: []u8,
    home: ?[]u8 = null,
    auth: ?[]u8 = null,
    email: ?[]u8 = null,
    repository: ?[]u8 = null,
    always_auth: ?bool = null,

    fn deinit(self: *Named, allocator: mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.url);
        if (self.home) |v| allocator.free(v);
        if (self.auth) |v| allocator.free(v);
        if (self.email) |v| allocator.free(v);
        if (self.repository) |v| allocator.free(v);
    }
};

const Builtin = struct {
    name: []const u8,
    url: []const u8,
    home: []const u8,
};

const builtin_registries = [_]Builtin{
    .{ .name = "npm", .url = "https://registry.npmjs.org/", .home = "https://www.npmjs.org" },
    .{ .name = "yarn", .url = "https://registry.yarnpkg.com/", .home = "https://yarnpkg.com" },
    .{ .name = "tencent", .url = "https://mirrors.tencent.com/npm/", .home = "https://mirrors.tencent.com/npm/" },
    .{ .name = "cnpm", .url = "https://r.cnpmjs.org/", .home = "https://cnpmjs.org" },
    .{ .name = "taobao", .url = "https://registry.npmmirror.com/", .home = "https://npmmirror.com" },
    .{ .name = "npmMirror", .url = "https://skimdb.npmjs.com/registry/", .home = "https://skimdb.npmjs.com/" },
    .{ .name = "huawei", .url = "https://repo.huaweicloud.com/repository/npm/", .home = "https://www.huaweicloud.com/special/npm-jingxiang.html" },
};

pub const Map = struct {
    default_url: ?[]u8 = null,
    current_name: ?[]u8 = null,
    names: std.ArrayList(Named) = .empty,
    scopes: std.ArrayList(Scope) = .empty,

    pub fn deinit(self: *Map, allocator: mem.Allocator) void {
        if (self.default_url) |url| allocator.free(url);
        if (self.current_name) |name| allocator.free(name);
        for (self.names.items) |*named| named.deinit(allocator);
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
        try self.upsertNameEx(allocator, name, url, null);
    }

    fn upsertNameEx(self: *Map, allocator: mem.Allocator, name: []const u8, url: []const u8, home: ?[]const u8) !void {
        for (self.names.items) |*named| {
            if (mem.eql(u8, named.name, name)) {
                const next = try allocator.dupe(u8, url);
                allocator.free(named.url);
                named.url = next;
                if (home) |h| {
                    if (named.home) |old| allocator.free(old);
                    named.home = try allocator.dupe(u8, h);
                }
                return;
            }
        }
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_url = try allocator.dupe(u8, url);
        errdefer allocator.free(owned_url);
        const owned_home: ?[]u8 = if (home) |h| try allocator.dupe(u8, h) else null;
        errdefer if (owned_home) |h| allocator.free(h);
        try self.names.append(allocator, .{
            .name = owned_name,
            .url = owned_url,
            .home = owned_home,
        });
        self.sortNames();
    }

    fn removeName(self: *Map, allocator: mem.Allocator, name: []const u8) bool {
        for (self.names.items, 0..) |*named, i| {
            if (!mem.eql(u8, named.name, name)) continue;
            named.deinit(allocator);
            _ = self.names.orderedRemove(i);
            return true;
        }
        return false;
    }

    fn findNamed(self: *Map, name: []const u8) ?*Named {
        for (self.names.items) |*named| {
            if (mem.eql(u8, named.name, name)) return named;
        }
        return null;
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

fn reportMsg(comptime message: i18n.Msg, args: anytype) !void {
    var buf: [512]u8 = undefined;
    try report(i18n.format(message, &buf, args));
}

pub fn printError(err: anyerror) !void {
    switch (err) {
        error.InvalidScope => try reportMsg(messages.scope_shape, .{}),
        error.InvalidUrl => try reportMsg(messages.registry_url, .{}),
        error.ScopeMissing => try reportMsg(messages.scope_missing, .{}),
        error.NoHome => try reportMsg(messages.no_home, .{}),
        error.NoMap => try reportMsg(messages.no_map, .{}),
        error.InvalidName => try reportMsg(messages.bad_registry_name, .{}),
        error.CurlMissing => try reportMsg(messages.curl_nrm, .{}),
        error.Explained => {},
        else => try reportMsg(messages.registry_failed, .{@errorName(err)}),
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
        try i18n.err(messages.no_registry_map, .{store});
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
    if (agent.json_mode) {
        var sink = agent.Sink.init(allocator);
        defer sink.deinit();
        try sink.beginObject();
        try sink.key("registries");
        try sink.beginArray();
        for (builtin_registries) |item| try writeRegistry(&sink, &map, item.name, item.url);
        for (map.names.items) |item| try writeRegistry(&sink, &map, item.name, item.url);
        try sink.endArray();
        try sink.endObject();
        try sink.flush();
        return;
    }
    const width = try listAlignmentWidth(allocator, root);
    for (builtin_registries) |item| try printNameLine(&map, item.name, item.url, width);
    for (map.names.items) |item| try printNameLine(&map, item.name, item.url, width);
}

fn writeRegistry(sink: *agent.Sink, map: *const Map, name: []const u8, url: []const u8) !void {
    try sink.beginObject();
    try sink.fieldString("name", name);
    try sink.fieldString("url", url);
    try sink.fieldBool("current", map.isCurrent(name, url));
    try sink.endObject();
}

pub fn current(allocator: mem.Allocator, root: []const u8, show_url: bool) !void {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    if (agent.json_mode) {
        const name: ?[]const u8 = if (map.current_name) |active| active else if (map.default_url) |url| map.lookupName(url) else null;
        const url: ?[]const u8 = if (map.current_name) |active| map.urlForName(active) orelse map.default_url else map.default_url;
        var sink = agent.Sink.init(allocator);
        defer sink.deinit();
        try sink.beginObject();
        if (name) |value| try sink.fieldString("name", value) else try sink.fieldNull("name");
        if (url) |value| try sink.fieldString("url", value) else try sink.fieldNull("url");
        try sink.endObject();
        try sink.flush();
        return;
    }
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
    const found = map.urlForName(name) orelse return nrmNotFound(name);
    const url = try allocator.dupe(u8, found);
    defer allocator.free(url);
    try map.setDefault(allocator, url);
    try map.assignCurrent(allocator, name);
    try save(allocator, root, &map);
    try nrmSuccess(messages.nrm_success_use, .{name});
    try syncMap(allocator, root, &map);
    map.deinit(allocator);
}

pub fn addName(allocator: mem.Allocator, root: []const u8, raw_name: []const u8, raw_url: []const u8) !void {
    try addNameWithHome(allocator, root, raw_name, raw_url, null);
}

pub fn addNameWithHome(allocator: mem.Allocator, root: []const u8, raw_name: []const u8, raw_url: []const u8, raw_home: ?[]const u8) !void {
    const name = try normalizeName(raw_name);
    if (mem.eql(u8, name, "auto")) {
        try i18n.err(messages.auto_reserved, .{});
        return error.Explained;
    }
    if (findBuiltin(name) != null) return nrmInternal(name, "add");
    const url = try normalizeUrl(raw_url);
    const url_slash = try ensureTrailingSlash(allocator, url);
    defer allocator.free(url_slash);
    var map = try loadOrEmpty(allocator, root);
    errdefer map.deinit(allocator);
    if (registryUrlTaken(&map, name, url_slash)) {
        var buf: [512]u8 = undefined;
        return agent.explain(i18n.format(messages.nrm_error_duplicate, &buf, .{}));
    }
    try map.upsertNameEx(allocator, name, url_slash, raw_home);
    try save(allocator, root, &map);
    try nrmSuccess(messages.nrm_success_add, .{ name, name, name });
    map.deinit(allocator);
}

fn registryUrlTaken(map: *const Map, name: []const u8, url: []const u8) bool {
    if (map.urlForName(name) != null) return true;
    for (builtin_registries) |item| {
        if (sameUrl(item.url, url)) return true;
    }
    for (map.names.items) |item| {
        if (sameUrl(item.url, url)) return true;
    }
    return false;
}

fn ensureTrailingSlash(allocator: mem.Allocator, url: []const u8) ![]u8 {
    if (url.len > 0 and url[url.len - 1] == '/') return allocator.dupe(u8, url);
    return std.fmt.allocPrint(allocator, "{s}/", .{url});
}

pub fn delName(allocator: mem.Allocator, root: []const u8, raw_name: []const u8) !void {
    const name = try normalizeName(raw_name);
    if (findBuiltin(name) != null) return nrmInternal(name, "delete");
    var map = try load(allocator, root);
    errdefer map.deinit(allocator);
    const deleted_url = map.urlForName(name) orelse return nrmNotFound(name);
    const was_active = if (map.default_url) |u| sameUrl(u, deleted_url) else false;
    if (!map.removeName(allocator, name)) return nrmNotFound(name);
    if (map.current_name) |active| {
        if (mem.eql(u8, active, name)) {
            const inferred = if (map.default_url) |url| map.lookupName(url) else null;
            try map.assignCurrent(allocator, inferred);
        }
    }
    try save(allocator, root, &map);
    try nrmSuccess(messages.nrm_success_del, .{name});
    map.deinit(allocator);
    if (was_active) {
        agent.nrm_quiet_sync = true;
        return useName(allocator, root, "npm");
    }
}

pub fn renameName(allocator: mem.Allocator, root: []const u8, raw_name: []const u8, raw_new: []const u8) !void {
    const name = try normalizeName(raw_name);
    const new_name = try normalizeName(raw_new);
    if (mem.eql(u8, name, new_name)) {
        var buf: [256]u8 = undefined;
        return agent.explain(i18n.format(messages.nrm_error_same_name, &buf, .{}));
    }
    if (findBuiltin(name) != null) return nrmInternal(name, "rename");
    var map = try load(allocator, root);
    errdefer map.deinit(allocator);
    const entry = map.findNamed(name) orelse return nrmNotFound(name);
    if (map.urlForName(new_name) != null) {
        var buf: [256]u8 = undefined;
        return agent.explain(i18n.format(messages.nrm_error_name_exists, &buf, .{new_name}));
    }
    const owned = try allocator.dupe(u8, new_name);
    allocator.free(entry.name);
    entry.name = owned;
    if (map.current_name) |active| {
        if (mem.eql(u8, active, name)) try map.assignCurrent(allocator, new_name);
    }
    try save(allocator, root, &map);
    try nrmSuccess(messages.nrm_success_rename, .{ name, new_name });
    map.deinit(allocator);
}

pub fn loginRegistry(allocator: mem.Allocator, root: []const u8, raw_name: []const u8, opts: LoginOpts) !void {
    const name = try normalizeName(raw_name);
    if (findBuiltin(name) != null) return nrmInternal(name, "set authorization information of");
    var map = try load(allocator, root);
    errdefer map.deinit(allocator);
    const entry = map.findNamed(name) orelse return nrmNotFound(name);
    const auth = if (opts.base64) |b|
        try allocator.dupe(u8, b)
    else if (opts.username != null and opts.password != null)
        try encodeBasicAuth(allocator, opts.username.?, opts.password.?)
    else {
        var buf: [256]u8 = undefined;
        return agent.explain(i18n.format(messages.nrm_error_auth_required, &buf, .{}));
    };
    errdefer allocator.free(auth);
    if (entry.auth) |old| allocator.free(old);
    entry.auth = auth;
    if (opts.always_auth) |v| entry.always_auth = v;
    if (opts.email) |mail| {
        if (entry.email) |old| allocator.free(old);
        entry.email = try allocator.dupe(u8, mail);
    }
    try save(allocator, root, &map);
    try nrmSuccess(messages.nrm_success_login, .{name});
    if (map.default_url) |active| {
        if (sameUrl(active, entry.url)) try syncMap(allocator, root, &map);
    }
    map.deinit(allocator);
}

pub fn setHostedRepo(allocator: mem.Allocator, root: []const u8, raw_name: []const u8, repo: []const u8) !void {
    const name = try normalizeName(raw_name);
    if (findBuiltin(name) != null) return nrmInternal(name, "set repository of");
    var map = try load(allocator, root);
    errdefer map.deinit(allocator);
    const entry = map.findNamed(name) orelse return nrmNotFound(name);
    if (entry.repository) |old| allocator.free(old);
    entry.repository = try allocator.dupe(u8, repo);
    try save(allocator, root, &map);
    try nrmSuccess(messages.nrm_success_set_repo, .{name});
    if (map.default_url) |active| {
        if (sameUrl(active, entry.url)) try syncMap(allocator, root, &map);
    }
    map.deinit(allocator);
}

pub fn setAttr(allocator: mem.Allocator, root: []const u8, raw_name: []const u8, attr: []const u8, value: []const u8) !void {
    const name = try normalizeName(raw_name);
    if (mem.eql(u8, attr, "repository")) {
        var buf: [256]u8 = undefined;
        return agent.explain(i18n.format(messages.nrm_error_use_set_repo, &buf, .{}));
    }
    if (findBuiltin(name) != null) return nrmInternal(name, "set attribute of");
    var map = try load(allocator, root);
    errdefer map.deinit(allocator);
    const entry = map.findNamed(name) orelse return nrmNotFound(name);
    if (mem.eql(u8, attr, "home")) {
        if (entry.home) |old| allocator.free(old);
        entry.home = try allocator.dupe(u8, value);
    } else if (mem.eql(u8, attr, "_auth") or mem.eql(u8, attr, "auth")) {
        if (entry.auth) |old| allocator.free(old);
        entry.auth = try allocator.dupe(u8, value);
    } else if (mem.eql(u8, attr, "email")) {
        if (entry.email) |old| allocator.free(old);
        entry.email = try allocator.dupe(u8, value);
    } else if (mem.eql(u8, attr, "always-auth")) {
        entry.always_auth = mem.eql(u8, value, "true");
    } else {
        return error.InvalidName;
    }
    try save(allocator, root, &map);
    try nrmSuccess(messages.nrm_success_set_attr, .{ attr, value, name });
    if (map.default_url) |active| {
        if (sameUrl(active, entry.url)) try syncMap(allocator, root, &map);
    }
    map.deinit(allocator);
}

pub fn setScopeNrm(allocator: mem.Allocator, root: []const u8, scope: []const u8, url: []const u8) !void {
    const scope_key = try normalizeScope(scope);
    try add(allocator, root, scope, url);
    try nrmSuccess(messages.nrm_success_set_scope, .{ scope_key, url });
}

pub fn delScopeNrm(allocator: mem.Allocator, root: []const u8, scope: []const u8) !void {
    const name = try normalizeScope(scope);
    try removeScope(allocator, root, scope);
    try nrmSuccess(messages.nrm_success_del_scope, .{name});
}

pub fn openHome(allocator: mem.Allocator, root: []const u8, raw_name: []const u8, browser: ?[]const u8) !void {
    const name = try normalizeName(raw_name);
    const home = homeForName(allocator, root, name) catch |err| switch (err) {
        error.HomeMissing => {
            var buf: [256]u8 = undefined;
            return agent.explain(i18n.format(messages.nrm_error_no_homepage, &buf, .{name}));
        },
        else => return err,
    };
    defer allocator.free(home);
    if (!host.isTty(.stdout())) {
        try stdout("{s}\n", .{home});
        return;
    }
    try launchBrowser(browser, home);
}

fn homeForName(allocator: mem.Allocator, root: []const u8, name: []const u8) ![]u8 {
    if (findBuiltin(name)) |entry| return allocator.dupe(u8, entry.home);
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    const entry = map.findNamed(name) orelse return error.HomeMissing;
    return if (entry.home) |h| allocator.dupe(u8, h) else error.HomeMissing;
}

fn launchBrowser(browser: ?[]const u8, url: []const u8) !void {
    const os_info = @import("builtin");
    if (os_info.os.tag == .windows) {
        const prog = if (browser) |b| b else "cmd";
        const argv = if (browser) |b|
            &[_][]const u8{ b, url }
        else
            &[_][]const u8{ "cmd", "/c", "start", "", url };
        _ = prog;
        try checkSpawn(try host.spawnWait(argv, null, .inherit));
        return;
    }
    if (os_info.os.tag == .macos) {
        const argv = if (browser) |b|
            &[_][]const u8{ "open", "-a", b, url }
        else
            &[_][]const u8{ "open", url };
        try checkSpawn(try host.spawnWait(argv, null, .inherit));
        return;
    }
    const argv = if (browser) |b|
        &[_][]const u8{ b, url }
    else
        &[_][]const u8{ "xdg-open", url };
    const term = try host.spawnWait(argv, null, .inherit);
    return checkSpawn(term);
}

fn checkSpawn(term: std.process.Child.Term) !void {
    switch (term) {
        .exited => |code| if (code != 0) return error.Explained,
        else => return error.Explained,
    }
}

fn encodeBasicAuth(allocator: mem.Allocator, user: []const u8, pass: []const u8) ![]u8 {
    const pair = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ user, pass });
    defer allocator.free(pair);
    const out_len = std.base64.standard.Encoder.calcSize(pair.len);
    const out = try allocator.alloc(u8, out_len);
    _ = std.base64.standard.Encoder.encode(out, pair);
    return out;
}

pub fn listScopes(allocator: mem.Allocator, root: []const u8) !void {
    var loaded = load(allocator, root) catch |err| switch (err) {
        error.NoMap => null,
        else => return err,
    };
    if (agent.json_mode) {
        var sink = agent.Sink.init(allocator);
        defer sink.deinit();
        try sink.beginObject();
        try sink.key("scopes");
        try sink.beginArray();
        if (loaded) |*map| {
            defer map.deinit(allocator);
            for (map.scopes.items) |scope| {
                try sink.beginObject();
                try sink.fieldString("scope", scope.name);
                try sink.fieldString("url", scope.url);
                try sink.endObject();
            }
        }
        try sink.endArray();
        try sink.endObject();
        try sink.flush();
        return;
    }
    if (loaded) |*map| {
        defer map.deinit(allocator);
        if (map.scopes.items.len == 0) {
            try i18n.out(messages.no_scopes, .{});
            return;
        }
        for (map.scopes.items) |scope| try stdout("{s} {s}\n", .{ scope.name, scope.url });
        return;
    }
    try i18n.out(messages.no_scopes, .{});
}

pub fn testRegistries(allocator: mem.Allocator, root: []const u8, only: ?[]const u8) !void {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    var entries: std.ArrayList(Named) = .empty;
    defer {
        for (entries.items) |item| {
            allocator.free(item.name);
            allocator.free(item.url);
        }
        entries.deinit(allocator);
    }
    if (only) |raw| {
        const name = try normalizeName(raw);
        const found = map.urlForName(name) orelse return explainMissing(name);
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
    if (agent.json_mode) {
        const samples = try measureEntries(allocator, entries.items);
        defer allocator.free(samples);
        var sink = agent.Sink.init(allocator);
        defer sink.deinit();
        try sink.beginObject();
        try sink.key("registries");
        try sink.beginArray();
        for (entries.items, 0..) |item, i| {
            try sink.beginObject();
            try sink.fieldString("name", item.name);
            try sink.fieldBool("ok", samples[i].ok);
            if (samples[i].ok) {
                try sink.fieldString("seconds", samples[i].seconds());
            } else {
                try sink.fieldNull("seconds");
            }
            try sink.endObject();
        }
        try sink.endArray();
        try sink.endObject();
        try sink.flush();
        if (only == null) try rememberRegistries(allocator, root, entries.items, samples);
        return;
    }
    const samples = try measureNrmEntries(allocator, entries.items);
    defer allocator.free(samples);
    const width = blk: {
        var max: usize = 0;
        for (entries.items) |item| max = @max(max, item.name.len);
        break :blk max + 3;
    };
    var fastest: ?u32 = null;
    if (only == null) {
        for (samples) |sample| {
            if (!sample.ok) continue;
            const ms = sampleMs(&sample);
            if (fastest == null or ms < fastest.?) fastest = ms;
        }
    }
    const active_url = map.default_url;
    for (entries.items, samples) |item, sample| {
        try printNrmProbe(item.name, item.url, &sample, active_url, width, only == null, fastest);
    }
    if (only == null) {
        const cache = try measureEntries(allocator, entries.items);
        defer allocator.free(cache);
        try rememberRegistries(allocator, root, entries.items, cache);
    }
}

fn explainMissing(name: []const u8) error{Explained} {
    if (agent.nrm_cli) return nrmNotFound(name);
    var buf: [256]u8 = undefined;
    const message = i18n.format(messages.not_a_registry_plain, &buf, .{name});
    return agent.explain(message);
}

fn nrmProbeUrl(allocator: mem.Allocator, registry_url: []const u8) ![]u8 {
    if (registry_url.len > 0 and registry_url[registry_url.len - 1] == '/')
        return std.fmt.allocPrint(allocator, "{s}nrm", .{registry_url});
    return std.fmt.allocPrint(allocator, "{s}/nrm", .{registry_url});
}

fn measureNrmEntries(allocator: mem.Allocator, entries: []const Named) ![]@import("binary.zig").Sample {
    const binary = @import("binary.zig");
    const urls = try allocator.alloc([]const u8, entries.len);
    defer {
        for (urls) |url| allocator.free(url);
        allocator.free(urls);
    }
    for (entries, 0..) |item, i| urls[i] = try nrmProbeUrl(allocator, item.url);
    return binary.probeParallel(allocator, urls);
}

fn sampleMs(sample: *const @import("binary.zig").Sample) u32 {
    const secs = std.fmt.parseFloat(f64, sample.seconds()) catch return 0;
    return @intFromFloat(@round(secs * 1000.0));
}

fn printNrmProbe(name: []const u8, url: []const u8, sample: *const @import("binary.zig").Sample, active_url: ?[]const u8, width: usize, all: bool, fastest: ?u32) !void {
    var dashes: [128]u8 = undefined;
    const count = geneDashLine(name, width);
    @memset(dashes[0..count], '-');
    const star = if (active_url) |active| sameUrl(active, url) else false;
    const marker: []const u8 = if (star) "* " else "  ";
    const ms = sampleMs(sample);
    var suffix_buf: [160]u8 = undefined;
    const suffix: []const u8 = if (sample.ok) blk: {
        if (all and fastest != null and ms == fastest.?) {
            break :blk try std.fmt.bufPrint(&suffix_buf, "{d} ms", .{ms});
        }
        break :blk try std.fmt.bufPrint(&suffix_buf, "{d} ms", .{ms});
    } else if (isProbeTimeout(sample)) blk: {
        break :blk "timeout (Fetch timeout over 5000 ms)";
    } else blk: {
        break :blk try std.fmt.bufPrint(&suffix_buf, "{d} ms (Fetch error, if this is your private registry, please ignore)", .{ms});
    };
    try stdout("{s}{s} {s} {s}\n", .{ marker, name, dashes[0..count], suffix });
}

fn isProbeTimeout(sample: *const @import("binary.zig").Sample) bool {
    if (sample.ok) return false;
    const secs = std.fmt.parseFloat(f64, sample.seconds()) catch return false;
    return secs >= 4.9;
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
            try i18n.err(messages.no_registry_responded, .{});
            return error.Explained;
        };
        return useName(allocator, root, winner);
    }
    const samples = try measureEntries(allocator, entries.items);
    defer allocator.free(samples);
    try rememberRegistries(allocator, root, entries.items, samples);
    const winner = fastestSample(entries.items, samples) orelse {
        try i18n.err(messages.no_registry_responded, .{});
        return error.Explained;
    };
    return useName(allocator, root, winner);
}

fn collectEntries(allocator: mem.Allocator, root: []const u8, only: ?[]const u8) !std.ArrayList(Named) {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    var entries: std.ArrayList(Named) = .empty;
    errdefer freeEntries(allocator, &entries);
    if (only) |raw| {
        const name = try normalizeName(raw);
        const found = map.urlForName(name) orelse return explainMissing(name);
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

pub fn listAlignmentWidth(allocator: mem.Allocator, root: []const u8) !usize {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    var max: usize = 0;
    for (builtin_registries) |item| max = @max(max, item.name.len);
    for (map.names.items) |item| max = @max(max, item.name.len);
    return max + 3;
}

pub fn geneDashLine(name: []const u8, width: usize) usize {
    const want = if (width > name.len + 1) width - name.len + 1 else 2;
    return @max(want, 2);
}

fn printNameLine(map: *const Map, name: []const u8, url: []const u8, width: usize) !void {
    var dashes: [128]u8 = undefined;
    const count = geneDashLine(name, width);
    @memset(dashes[0..count], '-');
    const marker: []const u8 = if (map.isCurrent(name, url)) "* " else "  ";
    try stdout("{s}{s} {s} {s}\n", .{ marker, name, dashes[0..count], url });
}

fn nrmSuccess(comptime message: i18n.Msg, args: anytype) !void {
    if (agent.nrm_cli) {
        var buf: [512]u8 = undefined;
        const body = mem.trimEnd(u8, i18n.format(message, &buf, args), "\n");
        try stdout("{s}\n", .{body});
        return;
    }
    try i18n.out(message, args);
}

fn nrmNotFound(name: []const u8) error{Explained} {
    var buf: [256]u8 = undefined;
    const message = i18n.format(messages.nrm_error_registry_not_found, &buf, .{name});
    return agent.explain(message);
}

fn nrmInternal(name: []const u8, action: []const u8) error{Explained} {
    var buf: [256]u8 = undefined;
    _ = name;
    const message = i18n.format(messages.nrm_error_internal_registry, &buf, .{action});
    return agent.explain(message);
}

pub const LoginOpts = struct {
    base64: ?[]const u8 = null,
    username: ?[]const u8 = null,
    password: ?[]const u8 = null,
    email: ?[]const u8 = null,
    always_auth: ?bool = null,
};

pub fn guideCurrentRegistryIndex(allocator: mem.Allocator, names: []const []const u8, root: []const u8) usize {
    var map = loadOrEmpty(allocator, root) catch return 0;
    defer map.deinit(allocator);
    const active = map.current_name orelse return 0;
    for (names, 0..) |label, i| {
        if (mem.eql(u8, label, active)) return i;
    }
    return 0;
}

pub fn listRegistryLabels(allocator: mem.Allocator, root: []const u8) ![]const []const u8 {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    const count = builtin_registries.len + map.names.items.len;
    const out = try allocator.alloc([]const u8, count);
    errdefer allocator.free(out);
    var n: usize = 0;
    for (builtin_registries) |item| {
        out[n] = try allocator.dupe(u8, item.name);
        n += 1;
    }
    for (map.names.items) |item| {
        out[n] = try allocator.dupe(u8, item.name);
        n += 1;
    }
    return out;
}

pub fn listCustomLabels(allocator: mem.Allocator, root: []const u8) ![]const []const u8 {
    var map = try loadOrEmpty(allocator, root);
    defer map.deinit(allocator);
    const out = try allocator.alloc([]const u8, map.names.items.len);
    errdefer {
        for (out[0..map.names.items.len]) |label| allocator.free(label);
        allocator.free(out);
    }
    for (map.names.items, 0..) |item, i| out[i] = try allocator.dupe(u8, item.name);
    return out;
}

pub fn freeLabels(allocator: mem.Allocator, labels: []const []const u8) void {
    for (labels) |label| allocator.free(label);
    allocator.free(labels);
}

pub fn renderNpmrc(allocator: mem.Allocator, existing: []const u8, map: *const Map) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try appendKept(allocator, &out, existing, map, managedNpm);
    if (map.default_url) |url| try appendLine(allocator, &out, "registry={s}", .{url});
    if (authSource(map)) |entry| {
        if (entry.auth) |a| try appendLine(allocator, &out, "_auth={s}", .{a});
        if (entry.always_auth) |v| try appendLine(allocator, &out, "always-auth={s}", .{if (v) "true" else "false"});
        if (entry.email) |e| try appendLine(allocator, &out, "email={s}", .{e});
        if (entry.repository) |r| try appendLine(allocator, &out, "repository={s}", .{r});
    }
    for (map.scopes.items) |scope| {
        try appendLine(allocator, &out, "{s}:registry={s}", .{ scope.name, scope.url });
    }
    return out.toOwnedSlice(allocator);
}

fn authSource(map: *const Map) ?*const Named {
    const url = map.default_url orelse return null;
    for (map.names.items) |*named| {
        if (sameUrl(named.url, url)) return named;
    }
    return null;
}

pub fn renderYarnrc(allocator: mem.Allocator, existing: []const u8, map: *const Map) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
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
    var out: std.ArrayList(u8) = .empty;
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
    var out: std.ArrayList(u8) = .empty;
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
    if (agent.nrm_verbose_sync or (!agent.mirror_quiet and !agent.nrm_quiet_sync)) {
        try printMap(map);
        try i18n.err(messages.wrote_path, .{files.npmrc});
        try i18n.err(messages.wrote_path, .{files.yarnrc});
        try i18n.err(messages.wrote_path, .{files.yarnrc_yml});
        try i18n.err(messages.wrote_path, .{files.pnpmrc});
        try i18n.err(messages.wrote_path, .{files.bunfig});
    }
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
    const file = try std.Io.Dir.createFileAbsolute(host.io(), path, .{});
    defer file.close(host.io());
    try host.writeAll(file, body);
}

fn readOptional(allocator: mem.Allocator, path: []const u8) ![]u8 {
    const file = std.Io.Dir.openFileAbsolute(host.io(), path, .{}) catch |err| switch (err) {
        error.FileNotFound => return allocator.dupe(u8, ""),
        else => return err,
    };
    defer file.close(host.io());
    return host.readToEndAlloc(file, allocator, 1024 * 1024);
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
    try i18n.err(messages.sync_writes, .{
        files.npmrc,
        files.yarnrc,
        files.yarnrc_yml,
        files.pnpmrc,
        files.bunfig,
    });
}

fn printMap(map: *const Map) !void {
    if (map.default_url) |url| {
        try i18n.err(messages.default_url, .{url});
    } else {
        try i18n.err(messages.default_unset, .{});
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
    const StoredName = struct {
        name: []const u8,
        registry: []const u8,
        home: ?[]const u8 = null,
        auth: ?[]const u8 = null,
        email: ?[]const u8 = null,
        repository: ?[]const u8 = null,
        @"always-auth": ?bool = null,
    };
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
        try map.upsertNameEx(allocator, name, url, named.home);
        if (map.findNamed(name)) |entry| {
            if (named.auth) |a| {
                entry.auth = try allocator.dupe(u8, a);
            }
            if (named.email) |e| {
                entry.email = try allocator.dupe(u8, e);
            }
            if (named.repository) |r| {
                entry.repository = try allocator.dupe(u8, r);
            }
            if (named.@"always-auth") |v| entry.always_auth = v;
        }
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
    try std.Io.Dir.cwd().createDirPath(host.io(), root);
    map.sort();
    map.sortNames();
    var body: std.ArrayList(u8) = .empty;
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
        const line = try std.fmt.allocPrint(allocator, "    {{\"name\": {s}, \"registry\": {s}", .{ name, url });
        defer allocator.free(line);
        try body.appendSlice(allocator, line);
        if (named.home) |h| {
            const qh = try quote(allocator, h);
            defer allocator.free(qh);
            try body.appendSlice(allocator, ", \"home\": ");
            try body.appendSlice(allocator, qh);
        }
        if (named.auth) |a| {
            const qa = try quote(allocator, a);
            defer allocator.free(qa);
            try body.appendSlice(allocator, ", \"auth\": ");
            try body.appendSlice(allocator, qa);
        }
        if (named.email) |e| {
            const qe = try quote(allocator, e);
            defer allocator.free(qe);
            try body.appendSlice(allocator, ", \"email\": ");
            try body.appendSlice(allocator, qe);
        }
        if (named.repository) |r| {
            const qr = try quote(allocator, r);
            defer allocator.free(qr);
            try body.appendSlice(allocator, ", \"repository\": ");
            try body.appendSlice(allocator, qr);
        }
        if (named.always_auth) |v| {
            try body.appendSlice(allocator, if (v) ", \"always-auth\": true" else ", \"always-auth\": false");
        }
        try body.appendSlice(allocator, "}");
        try body.appendSlice(allocator, comma);
        try body.append(allocator, '\n');
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
    const file = try std.Io.Dir.createFileAbsolute(host.io(), path, .{});
    defer file.close(host.io());
    try host.writeAll(file, body.items);
}

const Env = struct {
    map: host.EnvMap,
    home: []const u8,
    xdg: ?[]const u8,

    fn deinit(self: *Env) void {
        self.map.deinit();
    }
};

fn openEnv(allocator: mem.Allocator) !Env {
    var env_map = try host.envMap(allocator);
    errdefer env_map.deinit();
    const home = @import("platform.zig").home(&env_map) orelse return error.NoHome;
    if (home.len == 0 or !fs.path.isAbsolute(home)) return error.NoHome;
    const xdg = env_map.get("XDG_CONFIG_HOME");
    const xdg_abs = if (xdg) |value| (if (value.len > 0 and fs.path.isAbsolute(value)) value else null) else null;
    return .{ .map = env_map, .home = home, .xdg = xdg_abs };
}

fn ensureParent(path: []const u8) !void {
    const parent = fs.path.dirname(path) orelse return;
    if (parent.len == 0) return;
    try std.Io.Dir.cwd().createDirPath(host.io(), parent);
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
    if (authSource(map) != null and (mem.eql(u8, key, "_auth") or mem.eql(u8, key, "always-auth") or mem.eql(u8, key, "email") or mem.eql(u8, key, "repository"))) return true;
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
    var out: std.ArrayList(u8) = .empty;
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
