const std = @import("std");
const windows = @import("builtin").os.tag == .windows;
const host = @import("host.zig");
const mem = std.mem;
const fs = std.fs;
const process = std.process;

const select = @import("select.zig");
const i18n = @import("i18n.zig");
const messages = @import("messages.zig");
const commands = @import("commands.zig");
const registry = @import("registry.zig");
const binary = @import("binary.zig");
const version = @import("version.zig");
const util = @import("util.zig");
const ZnvmConfig = @import("config.zig").ZnvmConfig;
const agent = @import("agent.zig");

const stderr = util.stderr;

pub const Mode = enum { session, step };

const Outcome = enum { quit, acted, back };
const Pick = union(enum) { quit, back, index: usize };
const Flow = enum { stay, back, leave_success, leave_quit };

const MenuCtx = struct {
    mode: Mode,
    zh: bool,
    shell_exports: bool,
    last_index: usize = 0,
};

const page_size: usize = 15;

pub fn runRegistry(allocator: mem.Allocator, config: ZnvmConfig) !void {
    if (comptime windows) {
        try stderr("Interactive menus are not supported on Windows yet; use --help.\n", .{});
        return;
    }
    if (!host.isTty(.stdin())) return;
    var ctx = MenuCtx{ .mode = .session, .zh = preferZh(allocator), .shell_exports = envHasNvmShell() };
    try registrySubmenu(allocator, config, &ctx);
}

pub fn runNrm(allocator: mem.Allocator, config: ZnvmConfig) !void {
    if (comptime windows) {
        try stderr("Interactive menus are not supported on Windows yet; use --help.\n", .{});
        return;
    }
    if (!agent.menuAllowed(.stdout)) return;
    const zh = preferZh(allocator);
    const items = [_][2][]const u8{
        .{ "Switch", "切换" },
        .{ "Test", "测速" },
        .{ "Add", "添加" },
        .{ "Delete", "删除" },
        .{ "Scopes", "scope" },
    };
    var last: usize = 0;
    while (true) {
        switch (try menuPairs(zh, "nrm", "nrm", &items, "Exit", "退出", last)) {
            .quit, .back => return,
            .index => |n| {
                last = n;
                switch (n) {
                    0 => try nrmSwitchPicker(allocator, config, zh),
                    1 => try nrmReg(allocator, config, zh, "nrm test", registryTestAll),
                    2 => try promptNrmAdd(allocator, config, zh),
                    3 => try nrmDeleteCustom(allocator, config, zh),
                    4 => try nrmScopeMenu(allocator, config, zh),
                    else => {},
                }
            },
        }
    }
}

fn nrmScopeMenu(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    while (true) {
        switch (try menuPairs(zh, "Scopes", "scope", &.{
            .{ "List", "列出" },
            .{ "Add", "添加" },
            .{ "Delete", "删除" },
        }, "Back", "返回", 0)) {
            .quit, .back => return,
            .index => |n| switch (n) {
                0 => try nrmShow(allocator, config, zh, "nrm scope ls", registry.listScopes),
                1 => try promptRegistryScope(allocator, config, zh, true),
                2 => try promptRegistryScope(allocator, config, zh, false),
                else => {},
            },
        }
    }
}

fn nrmDeleteCustom(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    const names = registry.listCustomLabels(allocator, config.root_dir) catch return;
    defer registry.freeLabels(allocator, names);
    if (names.len == 0) {
        try stderr("{s}\n", .{text(zh, "No custom registries.", "没有自定义源.")});
        return;
    }
    switch (try pickIndex(allocator, zh, names, 0)) {
        .quit, .back => return,
        .index => |i| {
            const choices = [_][]const u8{ text(zh, "No", "否"), text(zh, "Yes, delete", "确认删除") };
            switch (try choose(zh, names[i], &choices, text(zh, "Back", "返回"), 0)) {
                .index => |n| if (n == 1) {
                    try withGuide(allocator, registry.delName, .{ allocator, config.root_dir, names[i] });
                },
                else => {},
            }
        },
    }
}

fn nrmSwitchPicker(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    const names = try registry.listRegistryLabels(allocator, config.root_dir);
    defer registry.freeLabels(allocator, names);
    if (names.len == 0) return;
  switch (try pickIndex(allocator, zh, names, 0)) {
        .quit, .back => return,
        .index => |i| try withGuide(allocator, registry.useName, .{ allocator, config.root_dir, names[i] }),
    }
}

fn nrmPage(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, which: usize) !Outcome {
    return switch (which) {
        1 => nrmItems(allocator, config, zh, which, "Registries", "源", &.{
            .{ "List", "列出" },
            .{ "Use a name", "使用一个名字" },
            .{ "Add a name", "添加名字" },
            .{ "Delete a name", "删除名字" },
        }),
        2 => nrmItems(allocator, config, zh, which, "Scopes", "scope", &.{
            .{ "List", "列出" },
            .{ "Add a scope", "添加 scope" },
            .{ "Delete a scope", "删除 scope" },
        }),
        3 => nrmItems(allocator, config, zh, which, "Test and auto", "测速并自动选择", &.{
            .{ "Test registries", "测试源" },
            .{ "Use fastest registry", "使用最快的源" },
        }),
        else => .back,
    };
}

fn nrmItems(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, which: usize, en_title: []const u8, zh_title: []const u8, items: []const [2][]const u8) !Outcome {
    while (true) {
        switch (try menuPairs(zh, en_title, zh_title, items, "Back", "返回", 0)) {
            .quit => return .quit,
            .back => return .back,
            .index => |n| {
                try nrmDispatch(allocator, config, zh, which, n + 1);
                return .acted;
            },
        }
    }
}

fn nrmDispatch(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, menu: usize, item: usize) !void {
    switch (menu) {
        1 => switch (item) {
            1 => try nrmShow(allocator, config, zh, "nrm ls", registry.listNames),
            2 => try promptNrmName(allocator, config, zh, true),
            3 => try promptNrmAdd(allocator, config, zh),
            4 => try promptNrmName(allocator, config, zh, false),
            else => {},
        },
        2 => switch (item) {
            1 => try nrmShow(allocator, config, zh, "nrm scope ls", registry.listScopes),
            2 => try promptRegistryScope(allocator, config, zh, true),
            3 => try promptRegistryScope(allocator, config, zh, false),
            else => {},
        },
        3 => switch (item) {
            1 => try nrmReg(allocator, config, zh, "nrm test", registryTestAll),
            2 => try nrmReg(allocator, config, zh, "nrm use auto", registry.useAuto),
            else => {},
        },
        else => {},
    }
}

fn registryTestAll(allocator: mem.Allocator, root: []const u8) !void {
    try registry.testRegistries(allocator, root, null);
}

fn binaryTestAll(allocator: mem.Allocator, root: []const u8) !void {
    try binary.cmd(allocator, root, &.{"test"});
}

fn binaryUseChina(allocator: mem.Allocator, root: []const u8) !void {
    try binary.cmd(allocator, root, &.{ "use", "china" });
}

fn binaryUseOfficial(allocator: mem.Allocator, root: []const u8) !void {
    try binary.cmd(allocator, root, &.{ "use", "official" });
}

fn nrmShow(
    allocator: mem.Allocator,
    config: ZnvmConfig,
    zh: bool,
    label: []const u8,
    comptime func: fn (mem.Allocator, []const u8) anyerror!void,
) !void {
    try running(zh, label);
    show(func, .{ allocator, config.root_dir }) catch |err| try registry.printError(err);
}

fn nrmReg(
    allocator: mem.Allocator,
    config: ZnvmConfig,
    zh: bool,
    label: []const u8,
    comptime func: fn (mem.Allocator, []const u8) anyerror!void,
) !void {
    try running(zh, label);
    func(allocator, config.root_dir) catch |err| try registry.printError(err);
}

fn mirrorAction(
    allocator: mem.Allocator,
    config: ZnvmConfig,
    zh: bool,
    label: []const u8,
    comptime func: fn (mem.Allocator, []const u8) anyerror!void,
) !void {
    try running(zh, label);
    func(allocator, config.root_dir) catch |err| try binary.printError(err);
}

fn promptNrmName(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, using: bool) !void {
    try stderr("{s}\n", .{text(zh, "Registry name", "源名字")});
    const line = try prompt(allocator) orelse return;
    defer allocator.free(line);
    const name = mem.trim(u8, line, " \t");
    if (name.len == 0) return;
    if (!using) {
        try running(zh, "nrm del <name>");
        registry.delName(allocator, config.root_dir, name) catch |err| try registry.printError(err);
        return;
    }
    try running(zh, "nrm use <name>");
    registry.useName(allocator, config.root_dir, name) catch |err| try registry.printError(err);
}

fn promptNrmAdd(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    try stderr("{s}\n", .{text(zh, "Registry name", "源名字")});
    const name_line = try prompt(allocator) orelse return;
    defer allocator.free(name_line);
    const name = mem.trim(u8, name_line, " \t");
    if (name.len == 0) return;
    try stderr("{s}\n", .{text(zh, "Registry URL", "源地址")});
    const url_line = try prompt(allocator) orelse return;
    defer allocator.free(url_line);
    const url = mem.trim(u8, url_line, " \t");
    if (url.len == 0) return;
    try running(zh, "nrm add <name> <url>");
    registry.addName(allocator, config.root_dir, name, url) catch |err| try registry.printError(err);
}

fn promptBinarySet(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    try stderr("{s}\n", .{text(zh, "Mirror name (for example electron)", "镜像名字(例如 electron)")});
    const name_line = try prompt(allocator) orelse return;
    defer allocator.free(name_line);
    const name = mem.trim(u8, name_line, " \t");
    if (name.len == 0) return;
    try stderr("{s}\n", .{text(zh, "Mirror URL", "镜像地址")});
    const url_line = try prompt(allocator) orelse return;
    defer allocator.free(url_line);
    const url = mem.trim(u8, url_line, " \t");
    if (url.len == 0) return;
    try running(zh, "nvm mirror set <name> <url>");
    binary.cmd(allocator, config.root_dir, &.{ "set", name, url }) catch |err| try binary.printError(err);
}

pub fn run(allocator: mem.Allocator, config: ZnvmConfig, mode: Mode) !void {
    if (comptime windows) {
        try stderr("Interactive menus are not supported on Windows yet; use --help.\n", .{});
        return;
    }
    const stream: agent.MenuStream = if (mode == .step) .stderr else .stdout;
    if (!agent.menuAllowed(stream)) {
        try i18n.err(messages.guide_needs_terminal, .{ commands.program_name, commands.program_name });
        process.exit(1);
    }

    const zh = preferZh(allocator);
    var ctx = MenuCtx{
        .mode = mode,
        .zh = zh,
        .shell_exports = mode == .step or envHasNvmShell(),
    };
    while (true) {
        switch (try rootMenu(allocator, config, &ctx)) {
            .quit => {
                if (mode == .step) process.exit(2);
                return;
            },
            .acted => {
                if (mode == .step) return;
            },
            .back => {},
        }
    }
}

fn envHasNvmShell() bool {
    return host.getenv("NVM_SHELL") != null or host.getenv("ZSH_VERSION") != null or host.getenv("BASH_VERSION") != null;
}

fn preferZh(allocator: mem.Allocator) bool {
    i18n.init(allocator);
    return i18n.isZh();
}

fn text(zh: bool, en: []const u8, zh_text: []const u8) []const u8 {
    return if (zh) zh_text else en;
}

fn readLine(allocator: mem.Allocator) !?[]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    var byte: [1]u8 = undefined;
    while (true) {
        const n = std.posix.read(std.posix.STDIN_FILENO, &byte) catch return error.ReadFailed;
        if (n == 0) {
            if (list.items.len == 0) return null;
            break;
        }
        if (byte[0] == '\n') break;
        if (byte[0] == '\r') continue;
        if (list.items.len < 400) try list.append(allocator, byte[0]);
    }
    return try list.toOwnedSlice(allocator);
}

fn prompt(allocator: mem.Allocator) !?[]u8 {
    try stderr("\n> ", .{});
    return readLine(allocator);
}

fn promptLine(allocator: mem.Allocator) !?[]u8 {
    try tty.enter();
    defer tty.leave();
    try stderr("> ", .{});
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    while (true) {
        const byte = try readByte() orelse break;
        if (byte == '\n' or byte == '\r') break;
        if (byte == 0x1b) return null;
        if (byte >= 32 and byte < 127) try list.append(allocator, byte);
    }
    if (list.items.len == 0) return null;
    return try list.toOwnedSlice(allocator);
}

fn withGuide(allocator: mem.Allocator, comptime func: anytype, args: anytype) !void {
    _ = allocator;
    agent.guide_mode = true;
    defer agent.guide_mode = false;
    @call(.auto, func, args) catch return;
}

const posix = std.posix;

const tty = struct {
    var saved: posix.termios = undefined;
    var raw_on: bool = false;
    var hooked: bool = false;
    var depth: u8 = 0;
    var previous: [4]posix.Sigaction = undefined;
    const sigs = [_]posix.SIG{ .HUP, .INT, .QUIT, .TERM };

    fn enter() !void {
        if (depth == 0) try enable();
        depth += 1;
    }

    fn leave() void {
        if (depth == 0) return;
        depth -= 1;
        if (depth == 0) disable();
    }

    fn enable() !void {
        const fd = posix.STDIN_FILENO;
        var term = try posix.tcgetattr(fd);
        saved = term;
        term.lflag.ICANON = false;
        term.lflag.ECHO = false;
        term.lflag.IEXTEN = false;
        term.lflag.ISIG = false;
        term.iflag.ICRNL = false;
        term.iflag.IXON = false;
        term.cc[@as(usize, @backingInt(posix.V.MIN))] = 1;
        term.cc[@as(usize, @backingInt(posix.V.TIME))] = 0;
        try posix.tcsetattr(fd, .NOW, term);
        raw_on = true;
        installSignals();
    }

    fn disable() void {
        restoreTermios();
        if (!hooked) return;
        hooked = false;
        inline for (sigs, 0..) |sig, i| posix.sigaction(sig, &previous[i], null);
    }

    fn restoreTermios() void {
        if (!raw_on) return;
        raw_on = false;
        posix.tcsetattr(posix.STDIN_FILENO, .NOW, saved) catch {};
    }

    fn installSignals() void {
        if (hooked) return;
        const action = posix.Sigaction{
            .handler = .{ .handler = onSignal },
            .mask = posix.sigemptyset(),
            .flags = 0,
        };
        inline for (sigs, 0..) |sig, i| posix.sigaction(sig, &action, &previous[i]);
        hooked = true;
    }

    fn onSignal(sig: posix.SIG) callconv(.c) void {
        restoreTermios();
        depth = 0;
        if (hooked) {
            hooked = false;
            inline for (sigs, 0..) |want, i| {
                if (want == sig) posix.sigaction(sig, &previous[i], null);
            }
        }
        posix.raise(sig) catch {};
    }
};

var pending_keys: select.Keys = .{};
var pending_at: usize = 0;

fn readByte() !?u8 {
    var buf: [1]u8 = undefined;
    while (true) {
        const n = posix.read(posix.STDIN_FILENO, &buf) catch |err| switch (err) {
            error.WouldBlock => return null,
            else => return error.ReadFailed,
        };
        if (n == 0) return null;
        return buf[0];
    }
}

fn pollReady(timeout_ms: i32) !bool {
    var fds = [1]posix.pollfd{.{
        .fd = posix.STDIN_FILENO,
        .events = posix.POLL.IN,
        .revents = 0,
    }};
    while (true) {
        const ready = posix.poll(&fds, timeout_ms) catch |err| switch (err) {
            else => return error.ReadFailed,
        };
        return ready != 0;
    }
}

fn readMenuKey() !?select.Key {
    if (pending_at < pending_keys.len) {
        const key = pending_keys.items[pending_at];
        pending_at += 1;
        if (pending_at == pending_keys.len) {
            pending_keys.len = 0;
            pending_at = 0;
        }
        return key;
    }
    pending_keys.len = 0;
    pending_at = 0;
    var parser = select.Parser{};
    while (true) {
        const byte = try readByte() orelse {
            parser.flush(&pending_keys);
            break;
        };
        parser.feed(byte, &pending_keys);
        while (parser.mode != .ground) {
            if (!try pollReady(100)) {
                parser.flush(&pending_keys);
                break;
            }
            const more = try readByte() orelse {
                parser.flush(&pending_keys);
                break;
            };
            parser.feed(more, &pending_keys);
        }
        if (pending_keys.len > 0) break;
    }
    if (pending_keys.len == 0) return null;
    pending_at = 1;
    return pending_keys.items[0];
}

fn paintMenu(title: []const u8, labels: []const []const u8, back_label: []const u8, cursor: usize, status: []const u8, up: usize) !usize {
    var storage: [8192]u8 = undefined;
    var writer = std.Io.Writer.fixed(&storage);
    const lines = try select.writeFrame(&writer, .{
        .title = title,
        .labels = labels,
        .back = back_label,
        .cursor = cursor,
        .color = select.colorEnabled(host.getenv("NO_COLOR"), host.getenv("TERM")),
        .status = status,
        .up = up,
    });
    try stderr("{s}", .{storage[0..writer.end]});
    return lines;
}

pub fn pickOne(allocator: mem.Allocator, title_en: []const u8, title_zh: []const u8, labels: []const []const u8) !?usize {
    if (comptime windows) return null;
    const zh = preferZh(allocator);
    switch (try choose(zh, text(zh, title_en, title_zh), labels, text(zh, "Cancel", "取消"), 0)) {
        .index => |i| return i,
        .back, .quit => return null,
    }
}

fn choose(zh: bool, title: []const u8, labels: []const []const u8, back_label: []const u8, initial_cursor: usize) !Pick {
    try tty.enter();
    defer tty.leave();
    var state = select.Select.init(labels.len);
    state.cursor = @min(initial_cursor, labels.len);
    var status: []const u8 = "";
    var painted: usize = 0;
    while (true) {
        painted = try paintMenu(title, labels, back_label, state.cursor, status, painted);
        const key = try readMenuKey() orelse return .quit;
        switch (state.handle(key)) {
            .redraw => status = "",
            .invalid => status = text(zh, "Enter a number from the menu.", "请输入菜单中的编号."),
            .pick => |index| return .{ .index = index },
            .back => return .back,
            .quit => {
                if (key == .interrupt) {
                    try stderr("{s}\n", .{i18n.t(messages.guide_cancelled)});
                    tty.leave();
                    process.exit(130);
                }
                return .quit;
            },
        }
    }
}

fn menuPairs(zh: bool, title_en: []const u8, title_zh: []const u8, items: []const [2][]const u8, back_en: []const u8, back_zh: []const u8, initial_cursor: usize) !Pick {
    var labels: [32][]const u8 = undefined;
    if (items.len > labels.len) return error.MenuTooLong;
    for (items, 0..) |item, i| labels[i] = text(zh, item[0], item[1]);
    return choose(zh, text(zh, title_en, title_zh), labels[0..items.len], text(zh, back_en, back_zh), initial_cursor);
}

fn rootMenu(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !Outcome {
    const zh = ctx.zh;
  var dynamic: [8][2][]const u8 = undefined;
    var n: usize = 0;
    const nvmrc = commands.peekCwdVersionSpec(allocator) catch null;
    defer if (nvmrc) |spec| allocator.free(spec);
    if (nvmrc) |spec| {
        var buf: [128]u8 = undefined;
        if (zh) {
            const label = std.fmt.bufPrint(&buf, "使用 .nvmrc ({s})", .{spec}) catch spec;
            dynamic[n] = .{ label, label };
        } else {
            const label = std.fmt.bufPrint(&buf, "Use .nvmrc ({s})", .{spec}) catch spec;
            dynamic[n] = .{ label, label };
        }
        n += 1;
    }
    const core = [_][2][]const u8{
        .{ "Switch version", "切换版本" },
        .{ "Install Node", "安装 Node" },
        .{ "Set default", "设置默认版本" },
        .{ "Manage versions", "管理版本" },
        .{ "Settings", "设置" },
    };
    for (core) |item| {
        dynamic[n] = item;
        n += 1;
    }
    var title_buf: [160]u8 = undefined;
    const status = try statusLine(allocator, config, zh);
    defer allocator.free(status);
    const title = if (zh)
        std.fmt.bufPrint(&title_buf, "{s}  {s}", .{ commands.program_name, status }) catch commands.program_name
    else
        std.fmt.bufPrint(&title_buf, "{s} — {s}", .{ commands.program_name, status }) catch commands.program_name;
    var labels: [32][]const u8 = undefined;
    for (dynamic[0..n], 0..) |item, i| labels[i] = if (nvmrc != null and i == 0) item[0] else text(zh, item[0], item[1]);
    const base_offset: usize = if (nvmrc != null) 1 else 0;
    while (true) {
        switch (try choose(zh, title, labels[0..n], text(zh, "Exit", "退出"), ctx.last_index)) {
            .quit, .back => return .quit,
            .index => |pick| {
                ctx.last_index = pick;
                const which = if (pick < base_offset) 0 else pick - base_offset + 1;
                switch (try submenu(allocator, config, ctx, which, nvmrc)) {
                    .back => continue,
                    .quit => return .quit,
                    .acted => return .acted,
                }
            },
        }
    }
}

fn statusLine(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) ![]u8 {
    const current = try commands.activeVersion(allocator, config);
    defer if (current) |v| allocator.free(v);
    const cur = current orelse text(zh, "none", "none");
    var buf: [192]u8 = undefined;
    if (zh) {
        return try allocator.dupe(u8, std.fmt.bufPrint(&buf, "当前 {s}", .{cur}) catch cur);
    }
    return try allocator.dupe(u8, std.fmt.bufPrint(&buf, "current {s}", .{cur}) catch cur);
}

fn submenu(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx, which: usize, nvmrc: ?[]const u8) !Outcome {
    _ = nvmrc;
    return switch (which) {
        0 => {
            try withGuide(allocator, commands.cmdUse, .{ allocator, &[_][]const u8{ commands.program_name, "use" }, config });
            return .acted;
        },
        1 => itemMenu(allocator, config, ctx, which, "Switch version", "切换版本", &.{
            .{ "Choose installed version", "选择已安装版本" },
            .{ "Use .nvmrc / .node-version here", "使用当前目录 .nvmrc" },
            .{ "Enter version or alias", "输入版本或 alias" },
        }, .leave_success),
        2 => itemMenu(allocator, config, ctx, which, "Install Node", "安装 Node", &.{
            .{ "Latest LTS", "最新 LTS" },
            .{ "Latest release", "最新版本" },
            .{ "Pick from short list / remote", "从列表中选择" },
            .{ "Enter a version", "输入版本号" },
        }, .leave_success),
        3 => itemMenu(allocator, config, ctx, which, "Set default", "设置默认版本", &.{
            .{ "Choose installed version", "选择已安装版本" },
        }, .leave_success),
        4 => itemMenu(allocator, config, ctx, which, "Manage versions", "管理版本", &.{
            .{ "List installed (ls)", "已安装列表" },
            .{ "Uninstall a version", "卸载版本" },
            .{ "Aliases", "别名" },
            .{ "Write .nvmrc (current)", "写入 .nvmrc" },
        }, .stay),
        5 => itemMenu(allocator, config, ctx, which, "Settings", "设置", &.{
            .{ "Node download mirrors", "Node 下载镜像" },
            .{ "npm registry & scopes", "npm 源与 scope" },
            .{ "Shell setup", "Shell 配置" },
        }, .stay),
        else => .back,
    };
}

fn itemMenu(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx, which: usize, en_title: []const u8, zh_title: []const u8, items: []const [2][]const u8, after: Flow) !Outcome {
    while (true) {
        switch (try menuPairs(ctx.zh, en_title, zh_title, items, "Back", "返回", ctx.last_index)) {
            .quit => return .quit,
            .back => return .back,
            .index => |n| {
                ctx.last_index = n;
                const flow = try dispatch(allocator, config, ctx, which, n + 1);
                switch (after) {
                    .stay => continue,
                    .leave_success => return .acted,
                    .back => return .back,
                    .leave_quit => return .quit,
                }
                _ = flow;
            },
        }
    }
}

fn dispatch(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx, menu: usize, item: usize) !Flow {
    switch (menu) {
        1 => switch (item) {
            1 => try pickInstalledUse(allocator, config, ctx),
            2 => try withGuide(allocator, commands.cmdUse, .{ allocator, &[_][]const u8{ commands.program_name, "use" }, config }),
            3 => try promptUse(allocator, config, ctx),
            else => {},
        },
        2 => switch (item) {
            1 => try runInstall(allocator, config, ctx, &.{"--lts"}, true),
            2 => try runInstall(allocator, config, ctx, &.{"node"}, true),
            3 => try installShortlist(allocator, config, ctx),
            4 => try promptInstall(allocator, config, ctx),
            else => {},
        },
        3 => switch (item) {
            1 => try pickInstalledDefault(allocator, config, ctx),
            else => {},
        },
        4 => switch (item) {
            1 => {
                try runShow(allocator, config, ctx.zh, "nvm ls", commands.cmdList, &.{"ls"});
                return .stay;
            },
            2 => try uninstallWizard(allocator, config, ctx),
            3 => try aliasSubmenu(allocator, config, ctx),
            4 => try createNvmrc(allocator, config, ctx),
            else => {},
        },
        5 => switch (item) {
            1 => try mirrorSubmenu(allocator, config, ctx),
            2 => try registrySubmenu(allocator, config, ctx),
            3 => {
                try explainHooks(ctx.zh);
                return .stay;
            },
            else => {},
        },
        else => {},
    }
    return .back;
}

fn registryAction(
    allocator: mem.Allocator,
    config: ZnvmConfig,
    zh: bool,
    label: []const u8,
    comptime func: fn (mem.Allocator, []const u8) anyerror!void,
) !void {
    try running(zh, label);
    func(allocator, config.root_dir) catch |err| try registry.printError(err);
}

fn promptRegistryScope(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, editing: bool) !void {
    try stderr("{s}\n", .{text(zh, "Scope (for example @company)", "scope(例如 @company)")});
    const scope_line = try prompt(allocator) orelse return;
    defer allocator.free(scope_line);
    const scope = mem.trim(u8, scope_line, " \t");
    if (scope.len == 0) return;
    if (!editing) {
        try running(zh, "nvm registry remove <@scope>");
        registry.removeScope(allocator, config.root_dir, scope) catch |err| try registry.printError(err);
        return;
    }
    try stderr("{s}\n", .{text(zh, "Registry URL", "源地址")});
    const url_line = try prompt(allocator) orelse return;
    defer allocator.free(url_line);
    const url = mem.trim(u8, url_line, " \t");
    if (url.len == 0) return;
    try running(zh, "nvm registry add <@scope> <url>");
    registry.add(allocator, config.root_dir, scope, url) catch |err| try registry.printError(err);
}

fn promptRegistryDefault(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    try stderr("{s}\n", .{text(zh, "Default registry URL", "默认源地址")});
    const line = try prompt(allocator) orelse return;
    defer allocator.free(line);
    const url = mem.trim(u8, line, " \t");
    if (url.len == 0) return;
    try running(zh, "nvm registry set-default <url>");
    registry.setDefault(allocator, config.root_dir, url) catch |err| try registry.printError(err);
}

fn running(zh: bool, command: []const u8) !void {
    try stderr("{s} {s}\n", .{ text(zh, "Running:", "正在执行:"), command });
}

fn show(comptime func: anytype, args: anytype) !void {
    if (host.isTty(.stdout())) return @call(.auto, func, args);
    const saved = std.c.dup(std.posix.STDOUT_FILENO);
    if (saved < 0) return error.DupFailed;
    defer _ = std.c.close(saved);
    if (std.c.dup2(std.posix.STDERR_FILENO, std.posix.STDOUT_FILENO) < 0) return error.DupFailed;
    defer _ = std.c.dup2(saved, std.posix.STDOUT_FILENO);
    return @call(.auto, func, args);
}

fn runShow(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, label: []const u8, comptime func: anytype, extra: []const []const u8) !void {
    try running(zh, label);
    var argv_buf = [_][]const u8{ "", "", "", "", "", "", "", "" };
    argv_buf[0] = commands.program_name;
    for (extra, 0..) |arg, i| argv_buf[i + 1] = arg;
    try show(func, .{ allocator, argv_buf[0 .. extra.len + 1], config });
}

fn runInstall(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx, extra: []const []const u8, with_default: bool) !void {
    var argv_buf = [_][]const u8{ "", "", "", "", "", "", "", "", "--silent" };
    var argc: usize = 2;
    argv_buf[0] = commands.program_name;
    argv_buf[1] = "install";
    for (extra, 0..) |arg, i| {
        argv_buf[i + 2] = arg;
        argc += 1;
    }
    if (!ctx.shell_exports) argv_buf[argc] = "--silent";
    const slice = if (ctx.shell_exports) argv_buf[0..argc] else argv_buf[0 .. argc + 1];
    try withGuide(allocator, commands.cmdInstall, .{ allocator, slice, config });
    try maybeOfferDefault(allocator, config, ctx, with_default);
}

fn runUseArgv(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx, extra: []const []const u8) !void {
    var argv_buf = [_][]const u8{ "", "", "", "", "", "", "" };
    argv_buf[0] = commands.program_name;
    argv_buf[1] = "use";
    for (extra, 0..) |arg, i| argv_buf[i + 2] = arg;
    const argc = 2 + extra.len;
    try withGuide(allocator, commands.cmdUse, .{ allocator, argv_buf[0..argc], config });
    if (!ctx.shell_exports and extra.len > 0) {
        var msg: [256]u8 = undefined;
        const line = i18n.format(messages.guide_run_in_shell, &msg, .{ commands.program_name, extra[0] });
        try stderr("{s}\n", .{line});
    }
}

fn promptInstall(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    try stderr("{s}\n", .{i18n.t(messages.guide_input_esc)});
    try stderr("{s}\n", .{text(ctx.zh, "Version (e.g. 22 or lts/hydrogen)", "版本(如 22 或 lts/hydrogen)")});
    const line = try promptLine(allocator) orelse return;
    defer allocator.free(line);
    const spec = mem.trim(u8, line, " \t");
    if (spec.len == 0) return;
    try runInstall(allocator, config, ctx, &.{spec}, true);
}

fn promptUse(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    try stderr("{s}\n", .{i18n.t(messages.guide_input_esc)});
    try stderr("{s}\n", .{text(ctx.zh, "Version or alias", "版本或 alias")});
    const line = try promptLine(allocator) orelse return;
    defer allocator.free(line);
    const spec = mem.trim(u8, line, " \t");
    if (spec.len == 0) return;
    try runUseArgv(allocator, config, ctx, &.{spec});
}

fn pickInstalledUse(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    const installed = try version.getInstalledVersions(allocator, config);
    defer {
        for (installed) |item| allocator.free(item);
        allocator.free(installed);
    }
    if (installed.len == 0) {
        try stderr("{s}\n", .{text(ctx.zh, "No versions installed.", "没有已安装的版本.")});
        return;
    }
    const cur = try commands.activeVersion(allocator, config);
    defer if (cur) |c| allocator.free(c);
    var start: usize = 0;
    for (installed, 0..) |ver, i| {
        if (cur) |active| {
            if (mem.eql(u8, active, ver)) start = i;
        }
    }
    switch (try pickIndex(allocator, ctx.zh, installed, start)) {
        .quit, .back => return,
        .index => |index| try runUseArgv(allocator, config, ctx, &.{installed[index]}),
    }
}

fn pickInstalledDefault(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    const installed = try version.getInstalledVersions(allocator, config);
    defer {
        for (installed) |item| allocator.free(item);
        allocator.free(installed);
    }
    if (installed.len == 0) {
        try stderr("{s}\n", .{text(ctx.zh, "No versions installed.", "没有已安装的版本.")});
        return;
    }
    const default_ver = commands.aliasTarget(allocator, config, "default") catch null;
    defer if (default_ver) |d| allocator.free(d);
    var labeled: [64][]const u8 = undefined;
    var owners: [64][]u8 = undefined;
    const current = try commands.activeVersion(allocator, config);
    defer if (current) |c| allocator.free(c);
    for (installed, 0..) |ver, i| {
        owners[i] = try labelVersion(allocator, ctx.zh, ver, current, default_ver);
        labeled[i] = owners[i][0..];
    }
    defer for (owners[0..installed.len]) |buf| allocator.free(buf);
    switch (try pickIndex(allocator, ctx.zh, labeled[0..installed.len], 0)) {
        .quit, .back => return,
        .index => |index| {
            const argv = [_][]const u8{ commands.program_name, "alias", "default", installed[index] };
            try withGuide(allocator, commands.cmdAlias, .{ allocator, &argv, config });
        },
    }
}

fn labelVersion(allocator: mem.Allocator, zh: bool, ver: []const u8, current: ?[]const u8, default_ver: ?[]const u8) ![]u8 {
    var tags: [6][]const u8 = undefined;
    var n: usize = 0;
    if (current) |active| if (mem.eql(u8, active, ver)) {
        tags[n] = text(zh, "current", "current");
        n += 1;
    };
    if (default_ver) |def| if (mem.eql(u8, def, ver) or mem.eql(u8, def, ver[1..])) {
        tags[n] = "default";
        n += 1;
    };
    var buf: [160]u8 = undefined;
    if (n == 0) return try allocator.dupe(u8, ver);
    var writer: std.Io.Writer = .fixed(&buf);
    try writer.writeAll(ver);
    try writer.writeAll(" (");
    for (tags[0..n], 0..) |tag, i| {
        if (i > 0) try writer.writeAll(", ");
        try writer.writeAll(tag);
    }
    try writer.writeAll(")");
    return try allocator.dupe(u8, buf[0..writer.end]);
}

fn installShortlist(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    try pickRemoteInstall(allocator, config, ctx);
}

fn maybeOfferDefault(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx, offer: bool) !void {
    if (!offer) return;
    const existing = commands.aliasTarget(allocator, config, "default") catch null;
    defer if (existing) |e| allocator.free(e);
    if (existing != null) return;
    const active = try commands.activeVersion(allocator, config);
    defer if (active) |a| allocator.free(a);
    const ver = active orelse return;
    const choices = [_][]const u8{
        text(ctx.zh, "No", "否"),
        text(ctx.zh, "Yes, set default", "设为默认"),
    };
    var title: [96]u8 = undefined;
    const head = if (ctx.zh)
        std.fmt.bufPrint(&title, "设置 default -> {s}?", .{ver}) catch ver
    else
        std.fmt.bufPrint(&title, "Set default -> {s}?", .{ver}) catch ver;
    switch (try choose(ctx.zh, head, &choices, text(ctx.zh, "Skip", "跳过"), 0)) {
        .index => |n| if (n == 1) {
            const argv = [_][]const u8{ commands.program_name, "alias", "default", ver };
            try withGuide(allocator, commands.cmdAlias, .{ allocator, &argv, config });
        },
        else => {},
    }
    try runUseArgv(allocator, config, ctx, &.{ver});
}

fn aliasSubmenu(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    const zh = ctx.zh;
    while (true) {
        switch (try menuPairs(zh, "Aliases", "别名", &.{
            .{ "Show aliases", "查看别名" },
            .{ "Set alias", "设置别名" },
            .{ "Delete alias", "删除别名" },
        }, "Back", "返回", ctx.last_index)) {
            .quit => return,
            .back => return,
            .index => |n| switch (n) {
                0 => try runShow(allocator, config, zh, "nvm alias", commands.cmdAlias, &.{"alias"}),
                1 => try promptAlias(allocator, config, zh),
                2 => try promptUnalias(allocator, config, zh),
                else => {},
            },
        }
    }
}

fn mirrorSubmenu(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    const zh = ctx.zh;
    while (true) {
        switch (try menuPairs(zh, "Mirrors", "下载镜像", &.{
            .{ "List", "列出" },
            .{ "Use china", "使用中国镜像" },
            .{ "Use official", "使用官方地址" },
            .{ "Test", "测速" },
            .{ "Use fastest", "使用最快" },
            .{ "Reset", "还原" },
        }, "Back", "返回", ctx.last_index)) {
            .quit => return,
            .back => return,
            .index => |n| switch (n) {
                0 => try mirrorAction(allocator, config, zh, "nvm mirror ls", binary.list),
                1 => try mirrorAction(allocator, config, zh, "nvm mirror use china", binaryUseChina),
                2 => try mirrorAction(allocator, config, zh, "nvm mirror use official", binaryUseOfficial),
                3 => try mirrorAction(allocator, config, zh, "nvm mirror test", binaryTestAll),
                4 => try mirrorAction(allocator, config, zh, "nvm mirror use auto", binary.useAuto),
                5 => try mirrorAction(allocator, config, zh, "nvm mirror reset", binary.reset),
                else => {},
            },
        }
    }
}

fn registrySubmenu(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    const zh = ctx.zh;
    while (true) {
        switch (try menuPairs(zh, "Registry", "npm 源", &.{
            .{ "Show map", "查看映射" },
            .{ "Scopes", "scope" },
            .{ "China default", "中国默认源" },
            .{ "Official", "恢复官方" },
        }, "Back", "返回", ctx.last_index)) {
            .quit => return,
            .back => return,
            .index => |n| switch (n) {
                0 => try registryAction(allocator, config, zh, "nvm registry show", registry.show),
                1 => try registryScopeSubmenu(allocator, config, ctx),
                2 => try registryAction(allocator, config, zh, "nvm registry china", registry.useChina),
                3 => try registryAction(allocator, config, zh, "nvm registry official", registry.useOfficial),
                else => {},
            },
        }
    }
}

fn registryScopeSubmenu(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    const zh = ctx.zh;
    while (true) {
        switch (try menuPairs(zh, "Scopes", "scope", &.{
            .{ "List", "列出" },
            .{ "Add / edit", "添加或修改" },
            .{ "Delete", "删除" },
        }, "Back", "返回", ctx.last_index)) {
            .quit, .back => return,
            .index => |n| switch (n) {
                0 => try registryAction(allocator, config, zh, "nvm registry scope ls", registry.listScopes),
                1 => try promptRegistryScope(allocator, config, zh, true),
                2 => try promptRegistryScope(allocator, config, zh, false),
                else => {},
            },
        }
    }
}

fn pickRemoteInstall(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    const zh = ctx.zh;
    try stderr("{s}\n", .{text(zh, "Fetching the remote list...", "正在获取远程列表...")});
    const labels = remoteLabels(allocator, config) catch |err| {
        try i18n.err(messages.fetch_index_nl, .{@errorName(err)});
        return;
    };
    defer {
        for (labels) |item| allocator.free(item);
        allocator.free(labels);
    }
    if (labels.len == 0) {
        try stderr("{s}\n", .{text(zh, "No remote versions found.\n", "远程列表是空的.\n")});
        return;
    }
    switch (try pickIndex(allocator, zh, labels, 0)) {
        .quit, .back => return,
        .index => |index| try runInstall(allocator, config, ctx, &.{labels[index]}, true),
    }
}

fn remoteLabels(allocator: mem.Allocator, config: ZnvmConfig) ![][]u8 {
    const index = try version.loadRemoteIndex(allocator, config);
    defer index.deinit();
    var list: std.ArrayList([]u8) = .empty;
    errdefer {
        for (list.items) |item| allocator.free(item);
        list.deinit(allocator);
    }
    for (index.value) |entry| {
        if (!version.isInstallable(entry, config.os, config.arch)) continue;
        if (entry.version.len < 2 or entry.version[0] != 'v') continue;
        _ = std.SemanticVersion.parse(entry.version[1..]) catch continue;
        try list.append(allocator, try allocator.dupe(u8, entry.version));
    }
    const Sorter = struct {
        fn newer(_: void, lhs: []u8, rhs: []u8) bool {
            const left = std.SemanticVersion.parse(lhs[1..]) catch return false;
            const right = std.SemanticVersion.parse(rhs[1..]) catch return true;
            return left.order(right) == .gt;
        }
    };
    mem.sort([]u8, list.items, {}, Sorter.newer);
    return list.toOwnedSlice(allocator);
}

fn pickIndex(allocator: mem.Allocator, zh: bool, labels: anytype, initial_cursor: usize) !Pick {
    _ = allocator;
    var page: usize = 0;
    while (true) {
        const start = page * page_size;
        const end = @min(start + page_size, labels.len);
        const shown = end - start;
        var rows: [17][]const u8 = undefined;
        const Row = enum { item, next, prev };
        var kind: [17]Row = undefined;
        var n: usize = 0;
        var row: usize = 0;
        while (row < shown) : (row += 1) {
            rows[n] = labels[start + row];
            kind[n] = .item;
            n += 1;
        }
        if (end < labels.len) {
            rows[n] = text(zh, "Next page", "下一页");
            kind[n] = .next;
            n += 1;
        }
        if (page > 0) {
            rows[n] = text(zh, "Previous page", "上一页");
            kind[n] = .prev;
            n += 1;
        }
        switch (try choose(zh, text(zh, "Choose", "选择"), rows[0..n], text(zh, "Back", "返回"), initial_cursor)) {
            .quit => return .quit,
            .back => return .back,
            .index => |index| switch (kind[index]) {
                .item => return .{ .index = start + index },
                .next => page += 1,
                .prev => page -= 1,
            },
        }
    }
}

fn createNvmrc(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    const zh = ctx.zh;
    const cwd = try host.cwdPath(allocator);
    defer allocator.free(cwd);
    const path = try fs.path.join(allocator, &.{ cwd, ".nvmrc" });
    defer allocator.free(path);
    if (std.Io.Dir.openFileAbsolute(host.io(), path, .{})) |file| {
        defer file.close(host.io());
        const body = try host.readToEndAlloc(file, allocator, 8192);
        defer allocator.free(body);
        try stderr("{s} {s}\n", .{ text(zh, ".nvmrc already exists:", ".nvmrc 已存在:"), mem.trim(u8, body, " \t\r\n") });
        return;
    } else |_| {}

    const current = try commands.activeVersion(allocator, config) orelse {
        try stderr("{s}\n", .{text(zh, "No active Node version to write.", "没有可写入的当前 Node 版本.")});
        return;
    };
    defer allocator.free(current);
    try runUseArgv(allocator, config, ctx, &.{ current, "--save" });
}

fn promptAlias(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    try stderr("{s}\n", .{text(zh, "Alias name", "别名")});
    const name_line = try prompt(allocator) orelse return;
    defer allocator.free(name_line);
    const name = mem.trim(u8, name_line, " \t");
    if (name.len == 0) return;
    const name_copy = try allocator.dupe(u8, name);
    defer allocator.free(name_copy);
    try stderr("{s}\n", .{text(zh, "Target version or alias", "目标版本或别名")});
    const target_line = try prompt(allocator) orelse return;
    defer allocator.free(target_line);
    const target = mem.trim(u8, target_line, " \t");
    if (target.len == 0) return;
    try running(zh, "nvm alias <name> <target>");
    const argv = [_][]const u8{ commands.program_name, "alias", name_copy, target };
    try commands.cmdAlias(allocator, &argv, config);
}

fn promptUnalias(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    try stderr("{s}\n", .{text(zh, "Alias name to delete", "要删除的别名")});
    const line = try prompt(allocator) orelse return;
    defer allocator.free(line);
    const name = mem.trim(u8, line, " \t");
    if (name.len == 0) return;
    try running(zh, "nvm unalias <name>");
    const argv = [_][]const u8{ commands.program_name, "unalias", name };
    try commands.cmdUnalias(allocator, &argv, config);
}

fn uninstallWizard(allocator: mem.Allocator, config: ZnvmConfig, ctx: *MenuCtx) !void {
    const zh = ctx.zh;
    const installed = try version.getInstalledVersions(allocator, config);
    defer {
        for (installed) |item| allocator.free(item);
        allocator.free(installed);
    }
    if (installed.len == 0) {
        try stderr("{s}\n", .{text(zh, "No versions installed.\n", "没有已安装的版本.\n")});
        return;
    }
    const picked = switch (try pickIndex(allocator, zh, installed, 0)) {
        .quit, .back => return,
        .index => |index| installed[index],
    };
    var title_buf: [160]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "{s} {s}", .{ text(zh, "Delete", "删除"), picked }) catch picked;
    const choices = [_][]const u8{
        text(zh, "No", "否"),
        text(zh, "Yes, uninstall", "确认删除"),
    };
    switch (try choose(zh, title, &choices, text(zh, "Back", "返回"), 1)) {
        .index => |n| if (n == 1) {
            const argv = [_][]const u8{ commands.program_name, "uninstall", picked };
            try withGuide(allocator, commands.cmdUninstall, .{ allocator, &argv, config });
        },
        else => {},
    }
}

fn explainCurl(zh: bool) !void {
    try stderr("{s}\n\ncurl -fsSL https://znvm.dev/install-as-nvm.sh | bash\n\n{s}\n", .{
        text(zh, "Install command (not run from this menu):", "安装命令(这个菜单不会替你执行):"),
        text(zh, "After it finishes, the command is nvm and versions live in ~/.nvm.", "结束后命令是 nvm, 版本在 ~/.nvm."),
    });
}

fn explainHooks(zh: bool) !void {
    const snippet =
        \\export NVM_DIR="$HOME/.nvm"
        \\[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    ;
    if (zh) {
        try stderr(
            \\bash 写在 ~/.bashrc, zsh 写在 ~/.zshrc:
            \\
            \\{s}
            \\
            \\fish 不会被安装脚本修改. nvm.sh 是 bash/zsh 文件, fish 不能 source 它.
            \\在 fish 里可以设置数据目录:
            \\
            \\set -gx NVM_DIR $HOME/.nvm
            \\
            \\切换版本仍使用 bash 或 zsh 里的 nvm 函数.
            \\
        , .{snippet});
    } else {
        try stderr(
            \\bash uses ~/.bashrc. zsh uses ~/.zshrc:
            \\
            \\{s}
            \\
            \\The installer does not edit fish config. nvm.sh is a bash/zsh file, so fish cannot source it.
            \\You can still set the data directory in fish:
            \\
            \\set -gx NVM_DIR $HOME/.nvm
            \\
            \\Switch versions from the nvm function in bash or zsh.
            \\
        , .{snippet});
    }
}

fn explainMirror(config: ZnvmConfig, zh: bool) !void {
    if (zh) {
        try stderr(
            \\默认下载镜像是 https://npmmirror.com/mirrors/node.
            \\设置 NVM_NODEJS_ORG_MIRROR 可以换成别的镜像.
            \\当前镜像: {s}
            \\
        , .{config.mirror});
    } else {
        try stderr(
            \\The default download mirror is https://npmmirror.com/mirrors/node.
            \\Set NVM_NODEJS_ORG_MIRROR to use a different mirror.
            \\Active mirror: {s}
            \\
        , .{config.mirror});
    }
}
