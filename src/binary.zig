const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;
const process = std.process;

const util = @import("util.zig");
const agent = @import("agent.zig");

const stdout = util.stdout;
const stderr = util.stderr;

fn report(message: []const u8) !void {
    if (agent.json_mode) agent.fail(1, message);
    try stderr("{s}\n", .{message});
}

const block_begin = "# nvm binaries begin";
const block_end = "# nvm binaries end";
const cache_ttl_secs: i64 = 6 * 60 * 60;
const probe_stack: usize = 256 * 1024;

const Slot = enum { env, npm };

const Bind = struct {
    slot: Slot,
    key: []const u8,
    china: []const u8,
};

const Tool = struct {
    name: []const u8,
    china_probe: []const u8,
    official_probe: []const u8,
    binds: []const Bind,
};

const tools = [_]Tool{
    .{
        .name = "electron",
        .china_probe = "https://cdn.npmmirror.com/binaries/electron/",
        .official_probe = "https://github.com/electron/electron/releases/download/",
        .binds = &.{
            .{ .slot = .env, .key = "ELECTRON_MIRROR", .china = "https://cdn.npmmirror.com/binaries/electron/" },
            .{ .slot = .npm, .key = "electron_mirror", .china = "https://cdn.npmmirror.com/binaries/electron/" },
        },
    },
    .{
        .name = "electron-builder",
        .china_probe = "https://cdn.npmmirror.com/binaries/electron-builder-binaries/",
        .official_probe = "https://github.com/electron-userland/electron-builder-binaries/releases/download/",
        .binds = &.{
            .{ .slot = .env, .key = "ELECTRON_BUILDER_BINARIES_MIRROR", .china = "https://cdn.npmmirror.com/binaries/electron-builder-binaries/" },
            .{ .slot = .npm, .key = "electron_builder_binaries_mirror", .china = "https://cdn.npmmirror.com/binaries/electron-builder-binaries/" },
        },
    },
    .{
        .name = "playwright",
        .china_probe = "https://cdn.npmmirror.com/binaries/playwright",
        .official_probe = "https://playwright.azureedge.net",
        .binds = &.{
            .{ .slot = .env, .key = "PLAYWRIGHT_DOWNLOAD_HOST", .china = "https://cdn.npmmirror.com/binaries/playwright" },
        },
    },
    .{
        .name = "cypress",
        .china_probe = "https://cdn.npmmirror.com/binaries/cypress",
        .official_probe = "https://download.cypress.io",
        .binds = &.{
            .{ .slot = .env, .key = "CYPRESS_DOWNLOAD_PATH_TEMPLATE", .china = "https://cdn.npmmirror.com/binaries/cypress/${version}/${platform}-${arch}/cypress.zip" },
        },
    },
    .{
        .name = "puppeteer",
        .china_probe = "https://cdn.npmmirror.com/binaries/chrome-for-testing",
        .official_probe = "https://storage.googleapis.com",
        .binds = &.{
            .{ .slot = .env, .key = "PUPPETEER_DOWNLOAD_HOST", .china = "https://cdn.npmmirror.com/binaries/chrome-for-testing" },
            .{ .slot = .env, .key = "PUPPETEER_DOWNLOAD_BASE_URL", .china = "https://cdn.npmmirror.com/binaries/chrome-for-testing" },
            .{ .slot = .env, .key = "PUPPETEER_CHROME_DOWNLOAD_BASE_URL", .china = "https://cdn.npmmirror.com/binaries/chrome-for-testing" },
            .{ .slot = .env, .key = "PUPPETEER_CHROME_HEADLESS_SHELL_DOWNLOAD_BASE_URL", .china = "https://cdn.npmmirror.com/binaries/chrome-for-testing" },
        },
    },
    .{
        .name = "node-sass",
        .china_probe = "https://cdn.npmmirror.com/binaries/node-sass",
        .official_probe = "https://github.com/sass/node-sass/releases/download",
        .binds = &.{
            .{ .slot = .env, .key = "SASS_BINARY_SITE", .china = "https://cdn.npmmirror.com/binaries/node-sass" },
            .{ .slot = .npm, .key = "sass_binary_site", .china = "https://cdn.npmmirror.com/binaries/node-sass" },
        },
    },
    .{
        .name = "sharp",
        .china_probe = "https://cdn.npmmirror.com/binaries/sharp",
        .official_probe = "https://github.com/lovell/sharp/releases/download",
        .binds = &.{
            .{ .slot = .env, .key = "npm_config_sharp_binary_host", .china = "https://cdn.npmmirror.com/binaries/sharp" },
            .{ .slot = .npm, .key = "sharp_binary_host", .china = "https://cdn.npmmirror.com/binaries/sharp" },
        },
    },
    .{
        .name = "libvips",
        .china_probe = "https://cdn.npmmirror.com/binaries/sharp-libvips",
        .official_probe = "https://github.com/lovell/sharp-libvips/releases/download/",
        .binds = &.{
            .{ .slot = .env, .key = "npm_config_sharp_libvips_binary_host", .china = "https://cdn.npmmirror.com/binaries/sharp-libvips" },
            .{ .slot = .npm, .key = "sharp_libvips_binary_host", .china = "https://cdn.npmmirror.com/binaries/sharp-libvips" },
        },
    },
    .{
        .name = "node",
        .china_probe = "https://cdn.npmmirror.com/binaries/node",
        .official_probe = "https://nodejs.org/dist",
        .binds = &.{
            .{ .slot = .env, .key = "NODEJS_ORG_MIRROR", .china = "https://cdn.npmmirror.com/binaries/node" },
            .{ .slot = .env, .key = "NVM_NODEJS_ORG_MIRROR", .china = "https://cdn.npmmirror.com/binaries/node" },
        },
    },
    .{
        .name = "chromedriver",
        .china_probe = "https://cdn.npmmirror.com/binaries/chromedriver",
        .official_probe = "https://googlechromelabs.github.io/chrome-for-testing",
        .binds = &.{
            .{ .slot = .env, .key = "CHROMEDRIVER_CDNURL", .china = "https://cdn.npmmirror.com/binaries/chromedriver" },
        },
    },
    .{
        .name = "edgedriver",
        .china_probe = "https://npmmirror.com/mirrors/edgedriver",
        .official_probe = "https://msedgedriver.azureedge.net",
        .binds = &.{
            .{ .slot = .env, .key = "EDGEDRIVER_CDNURL", .china = "https://npmmirror.com/mirrors/edgedriver" },
        },
    },
    .{
        .name = "operadriver",
        .china_probe = "https://cdn.npmmirror.com/binaries/operadriver",
        .official_probe = "https://github.com/operasoftware/operachromiumdriver/releases",
        .binds = &.{
            .{ .slot = .env, .key = "OPERADRIVER_CDNURL", .china = "https://cdn.npmmirror.com/binaries/operadriver" },
        },
    },
    .{
        .name = "phantomjs",
        .china_probe = "https://cdn.npmmirror.com/binaries/phantomjs",
        .official_probe = "https://github.com/Medium/phantomjs/releases/download",
        .binds = &.{
            .{ .slot = .env, .key = "PHANTOMJS_CDNURL", .china = "https://cdn.npmmirror.com/binaries/phantomjs" },
        },
    },
    .{
        .name = "node-swc",
        .china_probe = "https://cdn.npmmirror.com/binaries/node-swc",
        .official_probe = "https://github.com/swc-project/swc/releases",
        .binds = &.{
            .{ .slot = .env, .key = "SWC_BINARY_SITE", .china = "https://cdn.npmmirror.com/binaries/node-swc" },
        },
    },
    .{
        .name = "nwjs",
        .china_probe = "https://cdn.npmmirror.com/binaries/nwjs/v",
        .official_probe = "https://dl.nwjs.io",
        .binds = &.{
            .{ .slot = .env, .key = "NWJS_URLBASE", .china = "https://cdn.npmmirror.com/binaries/nwjs/v" },
        },
    },
    .{
        .name = "sentry-cli",
        .china_probe = "https://cdn.npmmirror.com/binaries/sentry-cli",
        .official_probe = "https://downloads.sentry-cdn.com/sentry-cli",
        .binds = &.{
            .{ .slot = .env, .key = "SENTRYCLI_CDNURL", .china = "https://cdn.npmmirror.com/binaries/sentry-cli" },
        },
    },
    .{
        .name = "saucectl",
        .china_probe = "https://cdn.npmmirror.com/binaries/saucectl",
        .official_probe = "https://github.com/saucelabs/saucectl/releases",
        .binds = &.{
            .{ .slot = .env, .key = "SAUCECTL_INSTALL_BINARY_MIRROR", .china = "https://cdn.npmmirror.com/binaries/saucectl" },
        },
    },
    .{
        .name = "node-re2",
        .china_probe = "https://cdn.npmmirror.com/binaries/node-re2",
        .official_probe = "https://github.com/uhop/node-re2/releases",
        .binds = &.{
            .{ .slot = .env, .key = "RE2_DOWNLOAD_MIRROR", .china = "https://cdn.npmmirror.com/binaries/node-re2" },
            .{ .slot = .env, .key = "RE2_DOWNLOAD_SKIP_PATH", .china = "true" },
        },
    },
    .{
        .name = "prisma",
        .china_probe = "https://cdn.npmmirror.com/binaries/prisma",
        .official_probe = "https://binaries.prisma.sh",
        .binds = &.{
            .{ .slot = .env, .key = "PRISMA_ENGINES_MIRROR", .china = "https://cdn.npmmirror.com/binaries/prisma" },
        },
    },
    .{
        .name = "better-sqlite3",
        .china_probe = "https://cdn.npmmirror.com/binaries/better-sqlite3",
        .official_probe = "https://github.com/WiseLibs/better-sqlite3/releases/download",
        .binds = &.{
            .{ .slot = .env, .key = "npm_config_better_sqlite3_binary_host", .china = "https://cdn.npmmirror.com/binaries/better-sqlite3" },
            .{ .slot = .npm, .key = "better_sqlite3_binary_host", .china = "https://cdn.npmmirror.com/binaries/better-sqlite3" },
        },
    },
    .{
        .name = "isolated-vm",
        .china_probe = "https://cdn.npmmirror.com/binaries/isolated-vm",
        .official_probe = "https://github.com/laverdet/isolated-vm/releases/download",
        .binds = &.{
            .{ .slot = .env, .key = "npm_config_isolated_vm_binary_host", .china = "https://cdn.npmmirror.com/binaries/isolated-vm" },
            .{ .slot = .npm, .key = "isolated_vm_binary_host", .china = "https://cdn.npmmirror.com/binaries/isolated-vm" },
        },
    },
    .{
        .name = "keytar",
        .china_probe = "https://cdn.npmmirror.com/binaries/keytar",
        .official_probe = "https://github.com/atom/node-keytar/releases/download",
        .binds = &.{
            .{ .slot = .env, .key = "npm_config_keytar_binary_host", .china = "https://cdn.npmmirror.com/binaries/keytar" },
            .{ .slot = .npm, .key = "keytar_binary_host", .china = "https://cdn.npmmirror.com/binaries/keytar" },
        },
    },
    .{
        .name = "robotjs",
        .china_probe = "https://cdn.npmmirror.com/binaries/robotjs",
        .official_probe = "https://github.com/octalmage/robotjs/releases/download",
        .binds = &.{
            .{ .slot = .env, .key = "npm_config_robotjs_binary_host", .china = "https://cdn.npmmirror.com/binaries/robotjs" },
            .{ .slot = .npm, .key = "robotjs_binary_host", .china = "https://cdn.npmmirror.com/binaries/robotjs" },
        },
    },
    .{
        .name = "gl",
        .china_probe = "https://cdn.npmmirror.com/binaries/gl",
        .official_probe = "https://github.com/stackgl/headless-gl/releases/download",
        .binds = &.{
            .{ .slot = .env, .key = "npm_config_gl_binary_host", .china = "https://cdn.npmmirror.com/binaries/gl" },
            .{ .slot = .npm, .key = "gl_binary_host", .china = "https://cdn.npmmirror.com/binaries/gl" },
        },
    },
    .{
        .name = "corepack",
        .china_probe = "https://registry.npmmirror.com",
        .official_probe = "https://registry.npmjs.org",
        .binds = &.{
            .{ .slot = .env, .key = "COREPACK_NPM_REGISTRY", .china = "https://registry.npmmirror.com" },
        },
    },
    .{
        .name = "ripgrep",
        .china_probe = "https://registry.npmmirror.com/-/binary/ripgrep-prebuilt",
        .official_probe = "https://github.com/microsoft/ripgrep-prebuilt/releases/download",
        .binds = &.{
            .{ .slot = .env, .key = "RIPGREP_PREBUILT_BINARIES_MIRROR", .china = "https://registry.npmmirror.com/-/binary/ripgrep-prebuilt" },
        },
    },
};


pub const Sample = struct {
    ok: bool = false,
    missing_curl: bool = false,
    text: [32]u8 = undefined,
    text_len: u8 = 0,

    pub fn seconds(self: *const Sample) []const u8 {
        return self.text[0..self.text_len];
    }
};

pub const Row = struct {
    name: []const u8,
    ok: bool,
    seconds: []const u8,
};

pub const Hit = struct {
    ok: bool,
    seconds: []u8,

    pub fn deinit(self: *Hit, allocator: mem.Allocator) void {
        allocator.free(self.seconds);
    }
};

const Mode = enum { official, china, custom, auto };

const Override = struct {
    name: []u8,
    url: []u8,
};

const State = struct {
    mode: Mode = .official,
    overrides: std.ArrayList(Override) = .{},

    fn deinit(self: *State, allocator: mem.Allocator) void {
        for (self.overrides.items) |item| {
            allocator.free(item.name);
            allocator.free(item.url);
        }
        self.overrides.deinit(allocator);
    }

    fn find(self: *const State, name: []const u8) ?[]const u8 {
        for (self.overrides.items) |item| {
            if (mem.eql(u8, item.name, name)) return item.url;
        }
        return null;
    }

    fn put(self: *State, allocator: mem.Allocator, name: []const u8, url: []const u8) !void {
        for (self.overrides.items) |*item| {
            if (!mem.eql(u8, item.name, name)) continue;
            const next = try allocator.dupe(u8, url);
            allocator.free(item.url);
            item.url = next;
            return;
        }
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_url = try allocator.dupe(u8, url);
        errdefer allocator.free(owned_url);
        try self.overrides.append(allocator, .{ .name = owned_name, .url = owned_url });
    }
};

pub fn printError(err: anyerror) !void {
    switch (err) {
        error.InvalidUrl => try report("error: mirror must be an http:// or https:// URL."),
        error.CurlMissing => try report("error: curl is required for nvm mirror test."),
        error.NoHome => try report("error: HOME is not set."),
        error.Explained => {},
        else => {
            var buf: [160]u8 = undefined;
            const message = std.fmt.bufPrint(&buf, "error: mirror failed: {s}", .{@errorName(err)}) catch "error: mirror failed";
            try report(message);
        },
    }
}

pub fn printHelp() !void {
    try stdout(
        \\nvm mirror - download mirrors
        \\
        \\Commands:
        \\  ls
        \\  use <china|official|auto>
        \\  set <name> <url>
        \\  reset
        \\  test [name]
        \\
        \\china writes the npmmirror hosts, including the Node dist mirror.
        \\official clears them. set stores one URL.
        \\auto measures both sides and keeps the faster one.
        \\npm, pnpm, and yarn v1 keys go in their rc files.
        \\Env-only tools go in $NVM_DIR/binaries.env. A new shell sources it.
        \\Scope routes are not changed. test always measures again.
        \\--json writes one JSON object to stdout for ls and test.
        \\Latency is cached in $NVM_DIR/mirror-latency.json for 6 hours.
        \\Docker image mirrors are not set here.
        \\
    , .{});
}

pub fn cmd(allocator: mem.Allocator, root: []const u8, args: []const []const u8) !void {
    if (args.len == 0 or (args.len == 1 and (mem.eql(u8, args[0], "help") or mem.eql(u8, args[0], "--help") or mem.eql(u8, args[0], "-h")))) {
        try printHelp();
        if (args.len == 0) process.exit(1);
        return;
    }
    const sub = args[0];
    if ((mem.eql(u8, sub, "ls") or mem.eql(u8, sub, "list")) and args.len == 1) {
        return list(allocator, root);
    }
    if (mem.eql(u8, sub, "use") and args.len == 2) {
        if (mem.eql(u8, args[1], "auto")) return useAuto(allocator, root);
        if (mem.eql(u8, args[1], "china")) return useFixed(allocator, root, .china);
        if (mem.eql(u8, args[1], "official")) return useFixed(allocator, root, .official);
        try stderr("error: mirror profile must be china, official, or auto.\n", .{});
        return error.Explained;
    }
    if (mem.eql(u8, sub, "set") and args.len == 3) return setOne(allocator, root, args[1], args[2]);
    if (mem.eql(u8, sub, "reset") and args.len == 1) return reset(allocator, root);
    if (mem.eql(u8, sub, "test") and args.len == 1) return testMirrors(allocator, root, null);
    if (mem.eql(u8, sub, "test") and args.len == 2) return testMirrors(allocator, root, args[1]);
    try printHelp();
    process.exit(1);
}

pub fn list(allocator: mem.Allocator, root: []const u8) !void {
    var state = try loadState(allocator, root);
    defer state.deinit(allocator);
    if (agent.json_mode) {
        var sink = agent.Sink.init(allocator);
        defer sink.deinit();
        try sink.beginObject();
        try sink.fieldString("profile", @tagName(state.mode));
        try sink.key("mirrors");
        try sink.beginArray();
        for (tools) |tool| {
            try sink.beginObject();
            try sink.fieldString("name", tool.name);
            const url = activeUrl(&state, tool);
            if (url.len == 0) try sink.fieldNull("url") else try sink.fieldString("url", url);
            try sink.endObject();
        }
        try sink.endArray();
        try sink.endObject();
        try sink.flush();
        return;
    }
    try stdout("profile {s}\n", .{@tagName(state.mode)});
    for (tools) |tool| {
        const url = activeUrl(&state, tool);
        if (url.len == 0) {
            try stdout("  {s} (unset)\n", .{tool.name});
        } else {
            try stdout("* {s} {s}\n", .{ tool.name, url });
        }
    }
}

fn useFixed(allocator: mem.Allocator, root: []const u8, mode: Mode) !void {
    var state = State{ .mode = mode };
    defer state.deinit(allocator);
    try applyState(allocator, root, &state);
    try saveState(allocator, root, &state);
    try stdout("The mirrors have been changed to '{s}'.\n", .{@tagName(mode)});
}

fn setOne(allocator: mem.Allocator, root: []const u8, raw_name: []const u8, raw_url: []const u8) !void {
    const name = mem.trim(u8, raw_name, " \t");
    const index = findTool(name) orelse {
        try stderr("error: {s} is not a mirror.\n", .{name});
        return error.Explained;
    };
    const url = try normalizeUrl(raw_url);
    var state = try loadState(allocator, root);
    defer state.deinit(allocator);
    try materialize(allocator, &state);
    try state.put(allocator, tools[index].name, url);
    state.mode = .custom;
    try applyState(allocator, root, &state);
    try saveState(allocator, root, &state);
    try stdout("set {s}\n", .{tools[index].name});
}

pub fn reset(allocator: mem.Allocator, root: []const u8) !void {
    var state = State{};
    defer state.deinit(allocator);
    try applyState(allocator, root, &state);
    const path = try statePath(allocator, root);
    defer allocator.free(path);
    fs.deleteFileAbsolute(path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    try stdout("mirrors reset\n", .{});
}

fn testMirrors(allocator: mem.Allocator, root: []const u8, only: ?[]const u8) !void {
    const first: usize = if (only) |raw| findTool(mem.trim(u8, raw, " \t")) orelse {
        return explainMissing(mem.trim(u8, raw, " \t"));
    } else 0;
    const count: usize = if (only == null) tools.len else 1;
    const samples = try measureTools(allocator, first, count);
    defer allocator.free(samples);
    if (agent.json_mode) {
        var sink = agent.Sink.init(allocator);
        defer sink.deinit();
        try sink.beginObject();
        try sink.key("mirrors");
        try sink.beginArray();
        var j: usize = 0;
        while (j < count) : (j += 1) {
            const tool = tools[first + j];
            try sink.beginObject();
            try sink.fieldString("name", tool.name);
            try sink.key("china");
            try writeProbe(&sink, samples[j * 2]);
            try sink.key("official");
            try writeProbe(&sink, samples[j * 2 + 1]);
            try sink.endObject();
        }
        try sink.endArray();
        try sink.endObject();
        try sink.flush();
    } else {
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const tool = tools[first + i];
            try printSide(tool.name, "china", samples[i * 2]);
            try printSide(tool.name, "official", samples[i * 2 + 1]);
        }
    }
    if (only == null) {
        var rows: [tools.len * 2]BinRow = undefined;
        for (tools, 0..) |tool, n| {
            rows[n * 2] = .{ .name = tool.name, .side = "china", .ok = samples[n * 2].ok, .seconds = samples[n * 2].seconds() };
            rows[n * 2 + 1] = .{ .name = tool.name, .side = "official", .ok = samples[n * 2 + 1].ok, .seconds = samples[n * 2 + 1].seconds() };
        }
        try updateCache(allocator, root, null, &rows);
    }
}

pub fn useAuto(allocator: mem.Allocator, root: []const u8) !void {
    const cached = try cachedBinaries(allocator, root);
    defer if (cached) |hits| freeBinHits(allocator, hits);
    const samples = if (cached == null) try measureTools(allocator, 0, tools.len) else null;
    defer if (samples) |owned| allocator.free(owned);
    if (samples) |owned| {
        var rows: [tools.len * 2]BinRow = undefined;
        for (tools, 0..) |tool, n| {
            rows[n * 2] = .{ .name = tool.name, .side = "china", .ok = owned[n * 2].ok, .seconds = owned[n * 2].seconds() };
            rows[n * 2 + 1] = .{ .name = tool.name, .side = "official", .ok = owned[n * 2 + 1].ok, .seconds = owned[n * 2 + 1].seconds() };
        }
        try updateCache(allocator, root, null, &rows);
    }
    var any_ok = false;
    var state = State{ .mode = .auto };
    defer state.deinit(allocator);
    for (tools, 0..) |tool, n| {
        const china_ok = if (cached) |hits| hits[n * 2].ok else samples.?[n * 2].ok;
        const official_ok = if (cached) |hits| hits[n * 2 + 1].ok else samples.?[n * 2 + 1].ok;
        const china_s = if (cached) |hits| hits[n * 2].seconds else samples.?[n * 2].seconds();
        const official_s = if (cached) |hits| hits[n * 2 + 1].seconds else samples.?[n * 2 + 1].seconds();
        if (china_ok or official_ok) any_ok = true;
        const url = if (preferChina(china_ok, china_s, official_ok, official_s)) primaryChina(tool) else "";
        try state.put(allocator, tool.name, url);
    }
    if (!any_ok) {
        try stderr("error: no mirror responded.\n", .{});
        return error.Explained;
    }
    try applyState(allocator, root, &state);
    try saveState(allocator, root, &state);
    try stdout("The mirrors have been changed to 'auto'.\n", .{});
}

pub fn probeParallel(allocator: mem.Allocator, urls: []const []const u8) ![]Sample {
    const samples = try allocator.alloc(Sample, urls.len);
    errdefer allocator.free(samples);
    for (samples) |*sample| sample.* = .{};
    if (urls.len == 0) return samples;
    const threads = try allocator.alloc(std.Thread, urls.len);
    defer allocator.free(threads);
    var started: usize = 0;
    errdefer {
        for (threads[0..started]) |*thread| thread.join();
    }
    for (urls, 0..) |url, i| {
        threads[i] = try std.Thread.spawn(.{ .stack_size = probe_stack }, probeWorker, .{ url, &samples[i] });
        started += 1;
    }
    for (threads[0..started]) |*thread| thread.join();
    started = 0;
    for (samples) |sample| {
        if (sample.missing_curl) return error.CurlMissing;
    }
    return samples;
}

pub fn cachedRegistries(allocator: mem.Allocator, root: []const u8, names: []const []const u8) !?[]Hit {
    const cache = try readCache(allocator, root) orelse return null;
    defer {
        cache.deinit(allocator);
        allocator.destroy(cache);
    }
    if (cache.registries_at == 0 or std.time.timestamp() - cache.registries_at >= cache_ttl_secs) return null;
    const hits = try allocator.alloc(Hit, names.len);
    errdefer allocator.free(hits);
    for (names, 0..) |name, i| {
        const row = cache.findReg(name) orelse {
            for (hits[0..i]) |*hit| hit.deinit(allocator);
            allocator.free(hits);
            return null;
        };
        hits[i] = .{ .ok = row.ok, .seconds = try allocator.dupe(u8, row.seconds) };
    }
    return hits;
}

pub fn storeRegistries(allocator: mem.Allocator, root: []const u8, rows: []const Row) !void {
    try updateCache(allocator, root, rows, null);
}

fn explainMissing(name: []const u8) error{Explained} {
    var buf: [256]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, "error: {s} is not a mirror.", .{name}) catch "error: is not a mirror.";
    return agent.explain(message);
}

fn writeProbe(sink: *agent.Sink, sample: Sample) !void {
    try sink.beginObject();
    try sink.fieldBool("ok", sample.ok);
    if (sample.ok) try sink.fieldString("seconds", sample.seconds()) else try sink.fieldNull("seconds");
    try sink.endObject();
}

fn printSide(name: []const u8, side: []const u8, sample: Sample) !void {
    if (!sample.ok) {
        try stdout("{s} {s} error\n", .{ name, side });
        return;
    }
    try stdout("{s} {s} {s}s\n", .{ name, side, sample.seconds() });
}

fn measureTools(allocator: mem.Allocator, first: usize, count: usize) ![]Sample {
    const urls = try allocator.alloc([]const u8, count * 2);
    defer allocator.free(urls);
    var i: usize = 0;
    while (i < count) : (i += 1) {
        urls[i * 2] = tools[first + i].china_probe;
        urls[i * 2 + 1] = tools[first + i].official_probe;
    }
    return probeParallel(allocator, urls);
}

fn preferChina(china_ok: bool, china_s: []const u8, official_ok: bool, official_s: []const u8) bool {
    if (!china_ok) return false;
    if (!official_ok) return true;
    const china_t = std.fmt.parseFloat(f64, china_s) catch return true;
    const official_t = std.fmt.parseFloat(f64, official_s) catch return true;
    return china_t <= official_t;
}

fn probeWorker(url: []const u8, out: *Sample) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const argv = [_][]const u8{
        "curl",
        "-o",
        "/dev/null",
        "-s",
        "-w",
        "%{time_total}",
        "--connect-timeout",
        "3",
        "--max-time",
        "5",
        url,
    };
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv,
        .max_output_bytes = 64,
    }) catch |err| {
        if (err == error.FileNotFound) out.missing_curl = true;
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    const exited = switch (result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
    if (!exited) return;
    const trimmed = mem.trim(u8, result.stdout, " \t\r\n");
    if (trimmed.len == 0 or trimmed.len > out.text.len) return;
    @memcpy(out.text[0..trimmed.len], trimmed);
    out.text_len = @intCast(trimmed.len);
    out.ok = true;
}

fn materialize(allocator: mem.Allocator, state: *State) !void {
    if (state.mode == .custom or state.mode == .auto) {
        for (tools) |tool| {
            if (state.find(tool.name) == null) try state.put(allocator, tool.name, "");
        }
        return;
    }
    var next = State{};
    errdefer next.deinit(allocator);
    for (tools) |tool| {
        const url: []const u8 = if (state.mode == .china) primaryChina(tool) else "";
        try next.put(allocator, tool.name, url);
    }
    state.deinit(allocator);
    state.* = next;
}

fn activeUrl(state: *const State, tool: Tool) []const u8 {
    switch (state.mode) {
        .official => return "",
        .china => return primaryChina(tool),
        .custom, .auto => return state.find(tool.name) orelse "",
    }
}

fn bindValue(state: *const State, tool: Tool, bind: Bind) ?[]const u8 {
    switch (state.mode) {
        .official => return null,
        .china => return bind.china,
        .custom, .auto => {
            const url = state.find(tool.name) orelse return null;
            if (url.len == 0) return null;
            if (isHttp(bind.china)) return url;
            return bind.china;
        },
    }
}

const Payloads = struct {
    npm: []u8,
    yarn: []u8,
    env: []u8,

    fn deinit(self: Payloads, allocator: mem.Allocator) void {
        allocator.free(self.npm);
        allocator.free(self.yarn);
        allocator.free(self.env);
    }
};

fn renderPayloads(allocator: mem.Allocator, state: *const State) !Payloads {
    var npm: std.ArrayList(u8) = .{};
    errdefer npm.deinit(allocator);
    var yarn: std.ArrayList(u8) = .{};
    errdefer yarn.deinit(allocator);
    var env: std.ArrayList(u8) = .{};
    errdefer env.deinit(allocator);
    for (tools) |tool| {
        for (tool.binds) |bind| {
            const value = bindValue(state, tool, bind) orelse continue;
            switch (bind.slot) {
                .npm => {
                    try appendLine(allocator, &npm, "{s}={s}", .{ bind.key, value });
                    const quoted = try quote(allocator, value);
                    defer allocator.free(quoted);
                    try appendLine(allocator, &yarn, "{s} {s}", .{ bind.key, quoted });
                },
                .env => try appendLine(allocator, &env, "export {s}='{s}'", .{ bind.key, value }),
            }
        }
    }
    return .{
        .npm = try npm.toOwnedSlice(allocator),
        .yarn = try yarn.toOwnedSlice(allocator),
        .env = try env.toOwnedSlice(allocator),
    };
}

fn applyState(allocator: mem.Allocator, root: []const u8, state: *const State) !void {
    var env_map = try openHome(allocator);
    defer env_map.deinit();
    const paths = try configPaths(allocator, env_map, root);
    defer paths.deinit(allocator);
    const payloads = try renderPayloads(allocator, state);
    defer payloads.deinit(allocator);
    if (try writeMarked(allocator, paths.npmrc, payloads.npm)) try stderr("Wrote {s}\n", .{paths.npmrc});
    if (try writeMarked(allocator, paths.yarnrc, payloads.yarn)) try stderr("Wrote {s}\n", .{paths.yarnrc});
    if (try writeMarked(allocator, paths.pnpmrc, payloads.npm)) try stderr("Wrote {s}\n", .{paths.pnpmrc});
    switch (try writeEnv(allocator, paths.envfile, payloads.env)) {
        .wrote => try stderr("Wrote {s}\n", .{paths.envfile}),
        .removed => try stderr("Removed {s}\n", .{paths.envfile}),
        .unchanged => {},
    }
}

const Paths = struct {
    npmrc: []u8,
    yarnrc: []u8,
    pnpmrc: []u8,
    envfile: []u8,

    fn deinit(self: Paths, allocator: mem.Allocator) void {
        allocator.free(self.npmrc);
        allocator.free(self.yarnrc);
        allocator.free(self.pnpmrc);
        allocator.free(self.envfile);
    }
};

fn configPaths(allocator: mem.Allocator, env_map: process.EnvMap, root: []const u8) !Paths {
    const home = env_map.get("HOME") orelse return error.NoHome;
    if (home.len == 0 or !fs.path.isAbsolute(home)) return error.NoHome;
    const xdg = env_map.get("XDG_CONFIG_HOME");
    const xdg_abs = if (xdg) |value| (if (value.len > 0 and fs.path.isAbsolute(value)) value else null) else null;
    const pnpmrc = if (xdg_abs) |dir|
        try fs.path.join(allocator, &.{ dir, "pnpm", "rc" })
    else if (builtin.os.tag == .macos)
        try fs.path.join(allocator, &.{ home, "Library", "Preferences", "pnpm", "rc" })
    else
        try fs.path.join(allocator, &.{ home, ".config", "pnpm", "rc" });
    return .{
        .npmrc = try fs.path.join(allocator, &.{ home, ".npmrc" }),
        .yarnrc = try fs.path.join(allocator, &.{ home, ".yarnrc" }),
        .pnpmrc = pnpmrc,
        .envfile = try fs.path.join(allocator, &.{ root, "binaries.env" }),
    };
}

fn writeMarked(allocator: mem.Allocator, path: []const u8, payload: []const u8) !bool {
    const existing = try readOptional(allocator, path);
    defer allocator.free(existing);
    const has_block = mem.indexOf(u8, existing, block_begin) != null;
    if (payload.len == 0 and !has_block) return false;
    const body = try patchMarked(allocator, existing, payload);
    defer allocator.free(body);
    try ensureParent(path);
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(body);
    return true;
}

const EnvWrite = enum { wrote, removed, unchanged };

fn writeEnv(allocator: mem.Allocator, path: []const u8, payload: []const u8) !EnvWrite {
    if (payload.len == 0) {
        fs.deleteFileAbsolute(path) catch |err| switch (err) {
            error.FileNotFound => return .unchanged,
            else => return err,
        };
        return .removed;
    }
    const body = try std.fmt.allocPrint(allocator, "{s}\n{s}{s}\n", .{ block_begin, payload, block_end });
    defer allocator.free(body);
    try ensureParent(path);
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(body);
    return .wrote;
}

fn patchMarked(allocator: mem.Allocator, existing: []const u8, payload: []const u8) ![]u8 {
    var kept: std.ArrayList(u8) = .{};
    errdefer kept.deinit(allocator);
    var i: usize = 0;
    while (i < existing.len) {
        const next = mem.indexOfScalarPos(u8, existing, i, '\n') orelse existing.len;
        const line = trimCr(existing[i..next]);
        i = if (next == existing.len) existing.len else next + 1;
        if (mem.eql(u8, mem.trim(u8, line, " \t"), block_begin)) {
            while (i < existing.len) {
                const end_rel = mem.indexOfScalarPos(u8, existing, i, '\n') orelse existing.len;
                const end_line = trimCr(existing[i..end_rel]);
                i = if (end_rel == existing.len) existing.len else end_rel + 1;
                if (mem.eql(u8, mem.trim(u8, end_line, " \t"), block_end)) break;
            }
            continue;
        }
        try kept.appendSlice(allocator, line);
        try kept.append(allocator, '\n');
    }
    if (payload.len == 0) return kept.toOwnedSlice(allocator);
    var out: std.ArrayList(u8) = .{};
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, block_begin);
    try out.append(allocator, '\n');
    try out.appendSlice(allocator, payload);
    if (payload.len == 0 or payload[payload.len - 1] != '\n') try out.append(allocator, '\n');
    try out.appendSlice(allocator, block_end);
    try out.append(allocator, '\n');
    try out.appendSlice(allocator, kept.items);
    kept.deinit(allocator);
    return out.toOwnedSlice(allocator);
}

fn loadState(allocator: mem.Allocator, root: []const u8) !State {
    const path = try statePath(allocator, root);
    defer allocator.free(path);
    const body = try readOptional(allocator, path);
    defer allocator.free(body);
    if (body.len == 0) return .{};
    const StoredValue = struct { name: []const u8, url: []const u8 };
    const Stored = struct {
        mode: []const u8 = "official",
        values: []const StoredValue = &.{},
    };
    const parsed = std.json.parseFromSlice(Stored, allocator, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    }) catch return .{};
    defer parsed.deinit();
    var state = State{ .mode = parseMode(parsed.value.mode) };
    errdefer state.deinit(allocator);
    if (state.mode == .custom or state.mode == .auto) {
        for (parsed.value.values) |item| {
            if (findTool(item.name) == null) continue;
            if (item.url.len != 0) _ = normalizeUrl(item.url) catch continue;
            try state.put(allocator, item.name, item.url);
        }
    }
    return state;
}

fn saveState(allocator: mem.Allocator, root: []const u8, state: *const State) !void {
    try ensureDir(root);
    var body: std.ArrayList(u8) = .{};
    defer body.deinit(allocator);
    try body.print(allocator, "{{\n  \"mode\": \"{s}\",\n  \"values\": [\n", .{@tagName(state.mode)});
    var written: usize = 0;
    const total: usize = if (state.mode == .custom or state.mode == .auto) state.overrides.items.len else 0;
    if (total > 0) {
        for (state.overrides.items) |item| {
            const name = try quote(allocator, item.name);
            defer allocator.free(name);
            const url = try quote(allocator, item.url);
            defer allocator.free(url);
            written += 1;
            const comma: []const u8 = if (written == total) "" else ",";
            const line = try std.fmt.allocPrint(allocator, "    {{\"name\": {s}, \"url\": {s}}}{s}\n", .{ name, url, comma });
            defer allocator.free(line);
            try body.appendSlice(allocator, line);
        }
    }
    try body.appendSlice(allocator, "  ]\n}\n");
    const path = try statePath(allocator, root);
    defer allocator.free(path);
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(body.items);
}

fn parseMode(raw: []const u8) Mode {
    if (mem.eql(u8, raw, "china")) return .china;
    if (mem.eql(u8, raw, "custom")) return .custom;
    if (mem.eql(u8, raw, "auto")) return .auto;
    return .official;
}

fn statePath(allocator: mem.Allocator, root: []const u8) ![]u8 {
    return fs.path.join(allocator, &.{ root, "binaries.json" });
}

fn cachePath(allocator: mem.Allocator, root: []const u8) ![]u8 {
    return fs.path.join(allocator, &.{ root, "mirror-latency.json" });
}

const BinRow = struct {
    name: []const u8,
    side: []const u8,
    ok: bool,
    seconds: []const u8,
};

const CacheReg = struct {
    name: []u8,
    ok: bool,
    seconds: []u8,
};

const CacheBin = struct {
    name: []u8,
    side: []u8,
    ok: bool,
    seconds: []u8,
};

const Cache = struct {
    registries_at: i64 = 0,
    binaries_at: i64 = 0,
    registries: std.ArrayList(CacheReg) = .{},
    binaries: std.ArrayList(CacheBin) = .{},

    fn deinit(self: *Cache, allocator: mem.Allocator) void {
        for (self.registries.items) |item| {
            allocator.free(item.name);
            allocator.free(item.seconds);
        }
        self.registries.deinit(allocator);
        for (self.binaries.items) |item| {
            allocator.free(item.name);
            allocator.free(item.side);
            allocator.free(item.seconds);
        }
        self.binaries.deinit(allocator);
    }

    fn findReg(self: *const Cache, name: []const u8) ?CacheReg {
        for (self.registries.items) |item| {
            if (mem.eql(u8, item.name, name)) return item;
        }
        return null;
    }
};

fn readCache(allocator: mem.Allocator, root: []const u8) !?*Cache {
    const path = try cachePath(allocator, root);
    defer allocator.free(path);
    const body = try readOptional(allocator, path);
    defer allocator.free(body);
    if (body.len == 0) return null;
    const ParsedReg = struct { name: []const u8, ok: bool, seconds: []const u8 };
    const ParsedBin = struct { name: []const u8, side: []const u8, ok: bool, seconds: []const u8 };
    const Parsed = struct {
        registries_at: i64 = 0,
        binaries_at: i64 = 0,
        registries: []const ParsedReg = &.{},
        binaries: []const ParsedBin = &.{},
    };
    const parsed = std.json.parseFromSlice(Parsed, allocator, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    }) catch return null;
    defer parsed.deinit();
    const cache = try allocator.create(Cache);
    cache.* = .{};
    errdefer {
        cache.deinit(allocator);
        allocator.destroy(cache);
    }
    cache.registries_at = parsed.value.registries_at;
    cache.binaries_at = parsed.value.binaries_at;
    for (parsed.value.registries) |item| {
        if (!safeToken(item.name) or !safeSeconds(item.seconds)) continue;
        try cache.registries.append(allocator, .{
            .name = try allocator.dupe(u8, item.name),
            .ok = item.ok,
            .seconds = try allocator.dupe(u8, item.seconds),
        });
    }
    for (parsed.value.binaries) |item| {
        if (!safeToken(item.name) or !safeToken(item.side) or !safeSeconds(item.seconds)) continue;
        try cache.binaries.append(allocator, .{
            .name = try allocator.dupe(u8, item.name),
            .side = try allocator.dupe(u8, item.side),
            .ok = item.ok,
            .seconds = try allocator.dupe(u8, item.seconds),
        });
    }
    return cache;
}

fn updateCache(allocator: mem.Allocator, root: []const u8, regs: ?[]const Row, bins: ?[]const BinRow) !void {
    var cache = try readCache(allocator, root) orelse blk: {
        const created = try allocator.create(Cache);
        created.* = .{};
        break :blk created;
    };
    defer {
        cache.deinit(allocator);
        allocator.destroy(cache);
    }
    const now = std.time.timestamp();
    if (regs) |rows| {
        for (cache.registries.items) |item| {
            allocator.free(item.name);
            allocator.free(item.seconds);
        }
        cache.registries.clearRetainingCapacity();
        cache.registries_at = now;
        for (rows) |row| {
            if (!safeToken(row.name)) continue;
            const seconds = if (safeSeconds(row.seconds)) row.seconds else "0";
            try cache.registries.append(allocator, .{
                .name = try allocator.dupe(u8, row.name),
                .ok = row.ok and safeSeconds(row.seconds),
                .seconds = try allocator.dupe(u8, seconds),
            });
        }
    }
    if (bins) |rows| {
        for (cache.binaries.items) |item| {
            allocator.free(item.name);
            allocator.free(item.side);
            allocator.free(item.seconds);
        }
        cache.binaries.clearRetainingCapacity();
        cache.binaries_at = now;
        for (rows) |row| {
            if (!safeToken(row.name) or !safeToken(row.side)) continue;
            const seconds = if (safeSeconds(row.seconds)) row.seconds else "0";
            try cache.binaries.append(allocator, .{
                .name = try allocator.dupe(u8, row.name),
                .side = try allocator.dupe(u8, row.side),
                .ok = row.ok and safeSeconds(row.seconds),
                .seconds = try allocator.dupe(u8, seconds),
            });
        }
    }
    try writeCache(allocator, root, cache);
}

fn writeCache(allocator: mem.Allocator, root: []const u8, cache: *const Cache) !void {
    try ensureDir(root);
    var body: std.ArrayList(u8) = .{};
    defer body.deinit(allocator);
    try body.print(allocator, "{{\n  \"registries_at\": {d},\n  \"binaries_at\": {d},\n  \"registries\": [\n", .{ cache.registries_at, cache.binaries_at });
    for (cache.registries.items, 0..) |item, i| {
        const comma: []const u8 = if (i + 1 == cache.registries.items.len) "" else ",";
        const line = try std.fmt.allocPrint(allocator, "    {{\"name\": \"{s}\", \"ok\": {s}, \"seconds\": \"{s}\"}}{s}\n", .{
            item.name,
            if (item.ok) "true" else "false",
            item.seconds,
            comma,
        });
        defer allocator.free(line);
        try body.appendSlice(allocator, line);
    }
    try body.appendSlice(allocator, "  ],\n  \"binaries\": [\n");
    for (cache.binaries.items, 0..) |item, i| {
        const comma: []const u8 = if (i + 1 == cache.binaries.items.len) "" else ",";
        const line = try std.fmt.allocPrint(allocator, "    {{\"name\": \"{s}\", \"side\": \"{s}\", \"ok\": {s}, \"seconds\": \"{s}\"}}{s}\n", .{
            item.name,
            item.side,
            if (item.ok) "true" else "false",
            item.seconds,
            comma,
        });
        defer allocator.free(line);
        try body.appendSlice(allocator, line);
    }
    try body.appendSlice(allocator, "  ]\n}\n");
    const path = try cachePath(allocator, root);
    defer allocator.free(path);
    const file = try fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(body.items);
}

const BinHit = struct {
    ok: bool,
    seconds: []u8,
};

fn cachedBinaries(allocator: mem.Allocator, root: []const u8) !?[]BinHit {
    const cache = try readCache(allocator, root) orelse return null;
    defer {
        cache.deinit(allocator);
        allocator.destroy(cache);
    }
    if (cache.binaries_at == 0 or std.time.timestamp() - cache.binaries_at >= cache_ttl_secs) return null;
    const hits = try allocator.alloc(BinHit, tools.len * 2);
    errdefer allocator.free(hits);
    for (tools, 0..) |tool, n| {
        const china = cacheFindBin(cache, tool.name, "china") orelse {
            freePartialBin(allocator, hits, n * 2);
            return null;
        };
        const official = cacheFindBin(cache, tool.name, "official") orelse {
            freePartialBin(allocator, hits, n * 2);
            return null;
        };
        hits[n * 2] = .{ .ok = china.ok, .seconds = try allocator.dupe(u8, china.seconds) };
        hits[n * 2 + 1] = .{ .ok = official.ok, .seconds = try allocator.dupe(u8, official.seconds) };
    }
    return hits;
}

fn cacheFindBin(cache: *const Cache, name: []const u8, side: []const u8) ?CacheBin {
    for (cache.binaries.items) |item| {
        if (mem.eql(u8, item.name, name) and mem.eql(u8, item.side, side)) return item;
    }
    return null;
}

fn freePartialBin(allocator: mem.Allocator, hits: []BinHit, n: usize) void {
    var i: usize = 0;
    while (i < n) : (i += 1) allocator.free(hits[i].seconds);
    allocator.free(hits);
}

fn freeBinHits(allocator: mem.Allocator, hits: []BinHit) void {
    for (hits) |hit| allocator.free(hit.seconds);
    allocator.free(hits);
}

fn safeToken(text: []const u8) bool {
    if (text.len == 0 or text.len > 64) return false;
    for (text) |char| {
        const ok = std.ascii.isAlphanumeric(char) or char == '-' or char == '_' or char == '.';
        if (!ok) return false;
    }
    return true;
}

fn safeSeconds(text: []const u8) bool {
    if (text.len == 0 or text.len > 16) return false;
    for (text) |char| {
        if (!(std.ascii.isDigit(char) or char == '.')) return false;
    }
    return true;
}

fn findTool(name: []const u8) ?usize {
    for (tools, 0..) |tool, i| {
        if (mem.eql(u8, tool.name, name)) return i;
    }
    return null;
}

fn primaryChina(tool: Tool) []const u8 {
    for (tool.binds) |bind| if (isHttp(bind.china)) return bind.china;
    return tool.china_probe;
}

fn isHttp(value: []const u8) bool {
    return mem.startsWith(u8, value, "https://") or mem.startsWith(u8, value, "http://");
}

fn normalizeUrl(raw: []const u8) ![]const u8 {
    const url = mem.trim(u8, raw, " \t");
    if (url.len < 8 or url.len > 400) return error.InvalidUrl;
    const https = mem.startsWith(u8, url, "https://");
    const http = mem.startsWith(u8, url, "http://");
    if (!https and !http) return error.InvalidUrl;
    if (mem.indexOfAny(u8, url, " \t\r\n\"'`") != null) return error.InvalidUrl;
    return url;
}

fn openHome(allocator: mem.Allocator) !process.EnvMap {
    return process.getEnvMap(allocator);
}

fn ensureDir(path: []const u8) !void {
    var root = try fs.openDirAbsolute("/", .{});
    defer root.close();
    const rel = if (path.len > 0 and path[0] == '/') path[1..] else path;
    if (rel.len == 0) return;
    try root.makePath(rel);
}

fn ensureParent(path: []const u8) !void {
    const parent = fs.path.dirname(path) orelse return;
    try ensureDir(parent);
}

fn readOptional(allocator: mem.Allocator, path: []const u8) ![]u8 {
    const file = fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return allocator.dupe(u8, ""),
        else => return err,
    };
    defer file.close();
    return file.readToEndAlloc(allocator, 1024 * 1024);
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

fn trimCr(line: []const u8) []const u8 {
    if (line.len > 0 and line[line.len - 1] == '\r') return line[0 .. line.len - 1];
    return line;
}

fn expectHas(haystack: []const u8, needle: []const u8) !void {
    if (mem.indexOf(u8, haystack, needle) == null) return error.TestExpectedEqual;
}

fn expectMissing(haystack: []const u8, needle: []const u8) !void {
    if (mem.indexOf(u8, haystack, needle) != null) return error.TestExpectedEqual;
}

test "binary marker round trip keeps registry lines" {
    const allocator = std.testing.allocator;
    const existing =
        \\fund=false
        \\registry=https://registry.npmjs.org
        \\@company:registry=https://npm.company.example
        \\//registry.npmjs.org/:_authToken=secret
        \\
    ;
    const patched = try patchMarked(allocator, existing, "electron_mirror=https://cdn.npmmirror.com/binaries/electron/\nsharp_libvips_binary_host=https://cdn.npmmirror.com/binaries/sharp-libvips\n");
    defer allocator.free(patched);
    try expectHas(patched, "# nvm binaries begin\n");
    try expectHas(patched, "electron_mirror=https://cdn.npmmirror.com/binaries/electron/\n");
    try expectHas(patched, "sharp_libvips_binary_host=https://cdn.npmmirror.com/binaries/sharp-libvips\n");
    try expectHas(patched, "fund=false\n");
    try expectHas(patched, "registry=https://registry.npmjs.org\n");
    try expectHas(patched, "@company:registry=https://npm.company.example\n");
    try expectHas(patched, "_authToken=secret\n");
    const cleared = try patchMarked(allocator, patched, "");
    defer allocator.free(cleared);
    try expectMissing(cleared, "nvm binaries");
    try expectMissing(cleared, "electron_mirror");
    try expectHas(cleared, "fund=false\n");
    try expectHas(cleared, "registry=https://registry.npmjs.org\n");
    try expectHas(cleared, "@company:registry=https://npm.company.example\n");
    try expectHas(cleared, "_authToken=secret\n");
}

test "china profile renders env and npm keys" {
    const allocator = std.testing.allocator;
    const state = State{ .mode = .china };
    const payloads = try renderPayloads(allocator, &state);
    defer payloads.deinit(allocator);
    try expectHas(payloads.npm, "electron_mirror=https://cdn.npmmirror.com/binaries/electron/\n");
    try expectHas(payloads.npm, "sharp_libvips_binary_host=https://cdn.npmmirror.com/binaries/sharp-libvips\n");
    try expectHas(payloads.npm, "sass_binary_site=https://cdn.npmmirror.com/binaries/node-sass\n");
    try expectHas(payloads.yarn, "electron_mirror \"https://cdn.npmmirror.com/binaries/electron/\"\n");
    try expectHas(payloads.env, "export ELECTRON_MIRROR='https://cdn.npmmirror.com/binaries/electron/'\n");
    try expectHas(payloads.env, "export PLAYWRIGHT_DOWNLOAD_HOST='https://cdn.npmmirror.com/binaries/playwright'\n");
    try expectHas(payloads.env, "export CYPRESS_DOWNLOAD_PATH_TEMPLATE='https://cdn.npmmirror.com/binaries/cypress/${version}/${platform}-${arch}/cypress.zip'\n");
    try expectHas(payloads.env, "export PUPPETEER_DOWNLOAD_HOST='https://cdn.npmmirror.com/binaries/chrome-for-testing'\n");
    try expectHas(payloads.env, "export SASS_BINARY_SITE='https://cdn.npmmirror.com/binaries/node-sass'\n");
    try expectHas(payloads.env, "export npm_config_sharp_libvips_binary_host='https://cdn.npmmirror.com/binaries/sharp-libvips'\n");
    try expectHas(payloads.env, "export RE2_DOWNLOAD_SKIP_PATH='true'\n");
    try expectMissing(payloads.env, "znvm");
    const official = State{};
    const empty = try renderPayloads(allocator, &official);
    defer empty.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), empty.npm.len);
    try std.testing.expectEqual(@as(usize, 0), empty.env.len);
}
