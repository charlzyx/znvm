const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const process = std.process;

const commands = @import("commands.zig");
const registry = @import("registry.zig");
const binary = @import("binary.zig");
const version = @import("version.zig");
const util = @import("util.zig");
const ZnvmConfig = @import("config.zig").ZnvmConfig;

const stderr = util.stderr;

pub const Mode = enum { session, step };

const Outcome = enum { quit, acted, back };
const Choice = union(enum) { again, invalid, back, pick: usize };
const Pick = union(enum) { quit, back, index: usize };

const page_size: usize = 15;

pub fn runRegistry(allocator: mem.Allocator, config: ZnvmConfig) !void {
    if (!std.posix.isatty(std.posix.STDIN_FILENO)) return;
    const zh = preferZh(allocator);
    while (true) {
        switch (try submenu(allocator, config, zh, 9)) {
            .quit, .back => return,
            .acted => if (!try pause(allocator, zh)) return,
        }
    }
}

pub fn runNrm(allocator: mem.Allocator, config: ZnvmConfig) !void {
    const agent = @import("agent.zig");
    if (!agent.menuAllowed(.stdout)) return;
    const zh = preferZh(allocator);
    const items = [_][2][]const u8{
        .{ "Registries", "源" },
        .{ "Scopes", "scope" },
        .{ "Test and auto", "测速并自动选择" },
    };
    while (true) {
        try stderr("\nnrm\n\n", .{});
        for (items, 0..) |item, i| {
            try stderr("  {d}  {s}\n", .{ i + 1, text(zh, item[0], item[1]) });
        }
        try stderr("  0  {s}\n", .{text(zh, "Exit", "退出")});
        const line = try prompt(allocator) orelse return;
        defer allocator.free(line);
        switch (parseChoice(line, items.len)) {
            .again => continue,
            .invalid => try sayInvalid(zh),
            .back => return,
            .pick => |n| switch (try nrmPage(allocator, config, zh, n)) {
                .quit => return,
                .back => continue,
                .acted => if (!try pause(allocator, zh)) return,
            },
        }
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
        try stderr("\n{s}\n\n", .{text(zh, en_title, zh_title)});
        try printItems(zh, items);
        const line = try prompt(allocator) orelse return .quit;
        defer allocator.free(line);
        switch (parseChoice(line, items.len)) {
            .again => continue,
            .invalid => {
                try sayInvalid(zh);
                continue;
            },
            .back => return .back,
            .pick => |n| {
                try nrmDispatch(allocator, config, zh, which, n);
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
    try binary.cmd(allocator, root, &.{ "test" });
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
    const agent = @import("agent.zig");
    const stream: agent.MenuStream = if (mode == .step) .stderr else .stdout;
    if (!agent.menuAllowed(stream)) {
        try stderr("{s}: interactive guide needs a terminal.\nRun `{s} help` for commands.\n", .{ commands.program_name, commands.program_name });
        process.exit(1);
    }

    const zh = preferZh(allocator);
    while (true) {
        switch (try rootMenu(allocator, config, zh)) {
            .quit => {
                if (mode == .step) process.exit(2);
                return;
            },
            .acted => {
                if (mode == .step) return;
                if (!try pause(allocator, zh)) return;
            },
            .back => {},
        }
    }
}

fn preferZh(allocator: mem.Allocator) bool {
    var env = process.getEnvMap(allocator) catch return false;
    defer env.deinit();
    const keys = [_][]const u8{ "LC_ALL", "LC_MESSAGES", "LANG" };
    for (keys) |key| {
        const value = env.get(key) orelse continue;
        if (value.len == 0) continue;
        if (mem.eql(u8, value, "C") or mem.eql(u8, value, "POSIX")) return false;
        return mem.startsWith(u8, value, "zh");
    }
    return false;
}

fn text(zh: bool, en: []const u8, zh_text: []const u8) []const u8 {
    return if (zh) zh_text else en;
}

fn readLine(allocator: mem.Allocator) !?[]u8 {
    var list: std.ArrayList(u8) = .{};
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

fn pause(allocator: mem.Allocator, zh: bool) !bool {
    try stderr("\n{s}", .{text(zh, "Press Enter to continue ", "回车继续 ")});
    const line = try readLine(allocator) orelse return false;
    allocator.free(line);
    return true;
}

fn parseChoice(raw: []const u8, max: usize) Choice {
    const trimmed = mem.trim(u8, raw, " \t");
    if (trimmed.len == 0) return .again;
    if (mem.eql(u8, trimmed, "0")) return .back;
    const n = std.fmt.parseInt(usize, trimmed, 10) catch return .invalid;
    if (n == 0 or n > max) return .invalid;
    return .{ .pick = n };
}

fn sayInvalid(zh: bool) !void {
    try stderr("{s}\n", .{text(zh, "Enter a number from the menu.", "请输入菜单中的编号.")});
}

fn printItems(zh: bool, items: []const [2][]const u8) !void {
    for (items, 0..) |item, i| {
        try stderr("  {d}  {s}\n", .{ i + 1, text(zh, item[0], item[1]) });
    }
    try stderr("  0  {s}\n", .{text(zh, "Back", "返回")});
}

fn rootMenu(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !Outcome {
    const items = [_][2][]const u8{
        .{ "Install Node", "安装 Node" },
        .{ "Switch version (use)", "切换版本(use)" },
        .{ "Show current", "查看当前(current)" },
        .{ "List versions (ls / ls-remote)", "列出版本(ls / ls-remote)" },
        .{ "Project", "项目管理" },
        .{ "Aliases", "别名(alias)" },
        .{ "Uninstall", "卸载(uninstall)" },
        .{ "Install / migrate (install-as-nvm)", "安装 / 迁移(install-as-nvm)" },
        .{ "Registries (scopes)", "镜像源(scope)" },
        .{ "Mirrors", "下载镜像" },
    };
    while (true) {
        try stderr("\n{s}{s}\n\n", .{ commands.program_name, text(zh, " (interactive guide)", "(交互引导)") });
        for (items, 0..) |item, i| {
            try stderr("  {d}  {s}\n", .{ i + 1, text(zh, item[0], item[1]) });
        }
        try stderr("  0  {s}\n", .{text(zh, "Exit", "退出")});
        const line = try prompt(allocator) orelse return .quit;
        defer allocator.free(line);
        switch (parseChoice(line, items.len)) {
            .again => continue,
            .invalid => try sayInvalid(zh),
            .back => return .quit,
            .pick => |n| switch (try submenu(allocator, config, zh, n)) {
                .back => continue,
                .quit => return .quit,
                .acted => return .acted,
            },
        }
    }
}

fn submenu(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, which: usize) !Outcome {
    return switch (which) {
        1 => itemMenu(allocator, config, zh, which, "Install Node", "安装 Node", &.{
            .{ "Install latest LTS", "装最新 LTS" },
            .{ "Install latest Current", "装最新 Current" },
            .{ "Enter a version (20.18.0 / lts/hydrogen)", "输入具体版本(如 20.18.0 / lts/hydrogen)" },
            .{ "Pick from the remote list, then install", "从远程列表里选一个再装" },
        }),
        2 => itemMenu(allocator, config, zh, which, "Switch version (use)", "切换版本(use)", &.{
            .{ "Choose an installed version", "选已安装版本" },
            .{ "Enter a version or alias (node, stable, lts/*)", "输入版本号 / alias(node, stable, lts/*)" },
            .{ "Use .nvmrc / .node-version in this directory", "按当前目录 .nvmrc / .node-version" },
        }),
        3 => itemMenu(allocator, config, zh, which, "Show current", "查看当前(current)", &.{
            .{ "Active version", "当前激活版本" },
            .{ "Path under NVM_DIR", "对应路径(NVM_DIR 下)" },
        }),
        4 => itemMenu(allocator, config, zh, which, "List versions", "列出版本", &.{
            .{ "Installed", "已安装" },
            .{ "Remote, all", "远程全部" },
            .{ "Remote, LTS only", "远程仅 LTS" },
        }),
        5 => itemMenu(allocator, config, zh, which, "Project", "项目管理", &.{
            .{ "Read .nvmrc and use", "读 .nvmrc 并 use" },
            .{ "Create .nvmrc with the current version if missing", "没有则创建 .nvmrc(写当前版本)" },
            .{ "Install the .nvmrc version, then use", "install 对齐 .nvmrc 再 use" },
        }),
        6 => itemMenu(allocator, config, zh, which, "Aliases", "别名(alias)", &.{
            .{ "Show aliases", "查看别名" },
            .{ "Set an alias", "设置别名" },
            .{ "Delete an alias", "删除别名" },
        }),
        7 => itemMenu(allocator, config, zh, which, "Uninstall", "卸载(uninstall)", &.{
            .{ "Choose an installed version", "选已安装版本卸载" },
            .{ "Confirm, then delete", "确认后再删" },
        }),
        8 => itemMenu(allocator, config, zh, which, "Install / migrate", "安装 / 迁移", &.{
            .{ "Print the install-as-nvm.sh curl (does not run it)", "指向官网 install-as-nvm.sh(打印 curl, 不替用户 curl)" },
            .{ "Shell hooks (bashrc / zshrc / fish)", "说明 shell 钩子(bashrc / zshrc / fish)" },
            .{ "Default npmmirror / NVM_NODEJS_ORG_MIRROR", "说明默认 npmmirror / NVM_NODEJS_ORG_MIRROR" },
        }),
        9 => itemMenu(allocator, config, zh, which, "Registries (scopes)", "镜像源(scope)", &.{
            .{ "View the current map", "查看当前映射" },
            .{ "Add or edit a scope", "添加或修改 scope" },
            .{ "Delete a scope", "删除 scope" },
            .{ "Set the default registry", "设置默认源" },
            .{ "China default, keep scopes", "中国默认源, 保留 scope" },
            .{ "Sync npm, yarn, pnpm, and bun", "同步 npm, yarn, pnpm, bun" },
            .{ "Restore the official registry", "恢复官方源" },
        }),
        10 => itemMenu(allocator, config, zh, which, "Mirrors", "下载镜像", &.{
            .{ "List", "列出" },
            .{ "Use china", "使用中国镜像" },
            .{ "Use official", "使用官方地址" },
            .{ "Set one mirror", "设置一个镜像" },
            .{ "Reset", "还原" },
            .{ "Test", "测速" },
            .{ "Use fastest", "使用最快的一边" },
        }),
        else => .back,
    };
}

fn itemMenu(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, which: usize, en_title: []const u8, zh_title: []const u8, items: []const [2][]const u8) !Outcome {
    while (true) {
        try stderr("\n{s}\n\n", .{text(zh, en_title, zh_title)});
        try printItems(zh, items);
        const line = try prompt(allocator) orelse return .quit;
        defer allocator.free(line);
        switch (parseChoice(line, items.len)) {
            .again => continue,
            .invalid => {
                try sayInvalid(zh);
                continue;
            },
            .back => return .back,
            .pick => |n| {
                try dispatch(allocator, config, zh, which, n);
                return .acted;
            },
        }
    }
}

fn dispatch(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, menu: usize, item: usize) !void {
    switch (menu) {
        1 => switch (item) {
            1 => try runInstall(allocator, config, zh, &.{"--lts"}, "nvm install --lts"),
            2 => try runInstall(allocator, config, zh, &.{"node"}, "nvm install node"),
            3 => try promptInstall(allocator, config, zh),
            4 => try pickRemoteInstall(allocator, config, zh),
            else => {},
        },
        2 => switch (item) {
            1 => try pickInstalledUse(allocator, config, zh),
            2 => try promptUse(allocator, config, zh),
            3 => try runUse(allocator, config, zh, &.{}, "nvm use"),
            else => {},
        },
        3 => switch (item) {
            1 => try runShow(allocator, config, zh, "nvm current", commands.cmdCurrent, &.{"current"}),
            2 => try runShow(allocator, config, zh, "nvm which current", commands.cmdWhich, &.{ "which", "current" }),
            else => {},
        },
        4 => switch (item) {
            1 => try runShow(allocator, config, zh, "nvm ls", commands.cmdList, &.{"ls"}),
            2 => try runShow(allocator, config, zh, "nvm ls-remote", commands.cmdListRemote, &.{"ls-remote"}),
            3 => try runShow(allocator, config, zh, "nvm ls-remote --lts", commands.cmdListRemote, &.{ "ls-remote", "--lts" }),
            else => {},
        },
        5 => switch (item) {
            1 => try runUse(allocator, config, zh, &.{}, "nvm use"),
            2 => try createNvmrc(allocator, config, zh),
            3 => try runInstall(allocator, config, zh, &.{}, "nvm install"),
            else => {},
        },
        6 => switch (item) {
            1 => try runShow(allocator, config, zh, "nvm alias", commands.cmdAlias, &.{"alias"}),
            2 => try promptAlias(allocator, config, zh),
            3 => try promptUnalias(allocator, config, zh),
            else => {},
        },
        7 => try uninstallWizard(allocator, config, zh),
        8 => switch (item) {
            1 => try explainCurl(zh),
            2 => try explainHooks(zh),
            3 => try explainMirror(config, zh),
            else => {},
        },
        9 => switch (item) {
            1 => try registryAction(allocator, config, zh, "nvm registry show", registry.show),
            2 => try promptRegistryScope(allocator, config, zh, true),
            3 => try promptRegistryScope(allocator, config, zh, false),
            4 => try promptRegistryDefault(allocator, config, zh),
            5 => try registryAction(allocator, config, zh, "nvm registry china", registry.useChina),
            6 => try registryAction(allocator, config, zh, "nvm registry sync", registry.sync),
            7 => try registryAction(allocator, config, zh, "nvm registry official", registry.useOfficial),
            else => {},
        },
        10 => switch (item) {
            1 => try mirrorAction(allocator, config, zh, "nvm mirror ls", binary.list),
            2 => try mirrorAction(allocator, config, zh, "nvm mirror use china", binaryUseChina),
            3 => try mirrorAction(allocator, config, zh, "nvm mirror use official", binaryUseOfficial),
            4 => try promptBinarySet(allocator, config, zh),
            5 => try mirrorAction(allocator, config, zh, "nvm mirror reset", binary.reset),
            6 => try mirrorAction(allocator, config, zh, "nvm mirror test", binaryTestAll),
            7 => try mirrorAction(allocator, config, zh, "nvm mirror use auto", binary.useAuto),
            else => {},
        },
        else => {},
    }
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
    if (std.posix.isatty(std.posix.STDOUT_FILENO)) return @call(.auto, func, args);
    const saved = try std.posix.dup(std.posix.STDOUT_FILENO);
    defer std.posix.close(saved);
    try std.posix.dup2(std.posix.STDERR_FILENO, std.posix.STDOUT_FILENO);
    defer std.posix.dup2(saved, std.posix.STDOUT_FILENO) catch {};
    return @call(.auto, func, args);
}

fn runShow(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, label: []const u8, comptime func: anytype, extra: []const []const u8) !void {
    try running(zh, label);
    var argv_buf = [_][]const u8{ "", "", "", "", "", "", "", "" };
    argv_buf[0] = commands.program_name;
    for (extra, 0..) |arg, i| argv_buf[i + 1] = arg;
    try show(func, .{ allocator, argv_buf[0 .. extra.len + 1], config });
}

fn runInstall(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, extra: []const []const u8, label: []const u8) !void {
    try running(zh, label);
    var argv_buf = [_][]const u8{ "", "", "", "", "", "", "", "" };
    argv_buf[0] = commands.program_name;
    argv_buf[1] = "install";
    for (extra, 0..) |arg, i| argv_buf[i + 2] = arg;
    try commands.cmdInstall(allocator, argv_buf[0 .. extra.len + 2], config);
}

fn runUse(allocator: mem.Allocator, config: ZnvmConfig, zh: bool, extra: []const []const u8, label: []const u8) !void {
    try running(zh, label);
    var argv_buf = [_][]const u8{ "", "", "", "", "", "", "", "" };
    argv_buf[0] = commands.program_name;
    argv_buf[1] = "use";
    for (extra, 0..) |arg, i| argv_buf[i + 2] = arg;
    try commands.cmdUse(allocator, argv_buf[0 .. extra.len + 2], config);
}

fn promptInstall(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    try stderr("{s}\n", .{text(zh, "Version (for example 20.18.0 or lts/hydrogen)", "版本(例如 20.18.0 或 lts/hydrogen)")});
    const line = try prompt(allocator) orelse return;
    defer allocator.free(line);
    const spec = mem.trim(u8, line, " \t");
    if (spec.len == 0) return;
    try runInstall(allocator, config, zh, &.{spec}, "nvm install <version>");
}

fn promptUse(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    try stderr("{s}\n", .{text(zh, "Version or alias (node, stable, lts/*)", "版本号或 alias(node, stable, lts/*)")});
    const line = try prompt(allocator) orelse return;
    defer allocator.free(line);
    const spec = mem.trim(u8, line, " \t");
    if (spec.len == 0) return;
    try runUse(allocator, config, zh, &.{spec}, "nvm use <version>");
}

fn pickInstalledUse(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    const installed = try version.getInstalledVersions(allocator, config);
    defer {
        for (installed) |item| allocator.free(item);
        allocator.free(installed);
    }
    if (installed.len == 0) {
        try stderr("{s}\n", .{text(zh, "No versions installed.\n", "没有已安装的版本.\n")});
        return;
    }
    switch (try pickIndex(allocator, zh, installed)) {
        .quit, .back => return,
        .index => |index| try runUse(allocator, config, zh, &.{installed[index]}, "nvm use <version>"),
    }
}

fn pickRemoteInstall(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    try stderr("{s}\n", .{text(zh, "Fetching the remote list...", "正在获取远程列表...")});
    const labels = remoteLabels(allocator, config) catch |err| {
        try stderr("error: Failed to fetch Node.js index ({s})\n", .{@errorName(err)});
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
    switch (try pickIndex(allocator, zh, labels)) {
        .quit, .back => return,
        .index => |index| try runInstall(allocator, config, zh, &.{labels[index]}, "nvm install <version>"),
    }
}

fn remoteLabels(allocator: mem.Allocator, config: ZnvmConfig) ![][]u8 {
    const index = try version.loadRemoteIndex(allocator, config);
    defer index.deinit();
    var list: std.ArrayList([]u8) = .{};
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

fn pickIndex(allocator: mem.Allocator, zh: bool, labels: anytype) !Pick {
    var page: usize = 0;
    while (true) {
        const start = page * page_size;
        const end = @min(start + page_size, labels.len);
        const shown = end - start;
        var max_choice = shown;
        var next_slot: ?usize = null;
        var prev_slot: ?usize = null;
        if (end < labels.len) {
            max_choice += 1;
            next_slot = max_choice;
        }
        if (page > 0) {
            max_choice += 1;
            prev_slot = max_choice;
        }
        try stderr("\n", .{});
        var row: usize = 0;
        while (row < shown) : (row += 1) {
            try stderr("  {d}  {s}\n", .{ row + 1, labels[start + row] });
        }
        if (next_slot) |slot| try stderr("  {d}  {s}\n", .{ slot, text(zh, "Next page", "下一页") });
        if (prev_slot) |slot| try stderr("  {d}  {s}\n", .{ slot, text(zh, "Previous page", "上一页") });
        try stderr("  0  {s}\n", .{text(zh, "Back", "返回")});
        const line = try prompt(allocator) orelse return .quit;
        defer allocator.free(line);
        switch (parseChoice(line, max_choice)) {
            .again => continue,
            .invalid => try sayInvalid(zh),
            .back => return .back,
            .pick => |n| {
                if (n <= shown) return .{ .index = start + n - 1 };
                if (next_slot != null and n == next_slot.?) page += 1;
                if (prev_slot != null and n == prev_slot.?) page -= 1;
            },
        }
    }
}

fn createNvmrc(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    const cwd = try fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);
    const path = try fs.path.join(allocator, &.{ cwd, ".nvmrc" });
    defer allocator.free(path);
    if (fs.openFileAbsolute(path, .{})) |file| {
        defer file.close();
        const body = try file.readToEndAlloc(allocator, 8192);
        defer allocator.free(body);
        try stderr("{s} {s}\n", .{ text(zh, ".nvmrc already exists:", ".nvmrc 已存在:"), mem.trim(u8, body, " \t\r\n") });
        return;
    } else |_| {}

    const current = try commands.activeVersion(allocator, config) orelse {
        try stderr("{s}\n", .{text(zh, "No active Node version to write.", "没有可写入的当前 Node 版本.")});
        return;
    };
    defer allocator.free(current);
    try runUse(allocator, config, zh, &.{ current, "--save" }, "nvm use <current> --save");
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

fn uninstallWizard(allocator: mem.Allocator, config: ZnvmConfig, zh: bool) !void {
    const installed = try version.getInstalledVersions(allocator, config);
    defer {
        for (installed) |item| allocator.free(item);
        allocator.free(installed);
    }
    if (installed.len == 0) {
        try stderr("{s}\n", .{text(zh, "No versions installed.\n", "没有已安装的版本.\n")});
        return;
    }
    const picked = switch (try pickIndex(allocator, zh, installed)) {
        .quit, .back => return,
        .index => |index| installed[index],
    };
    try stderr("\n{s} {s}\n", .{ text(zh, "Delete", "删除"), picked });
    try stderr("  1  {s}\n", .{text(zh, "Yes, uninstall", "确认删除")});
    try stderr("  2  {s}\n", .{text(zh, "Cancel", "取消")});
    try stderr("  0  {s}\n", .{text(zh, "Back", "返回")});
    const line = try prompt(allocator) orelse return;
    defer allocator.free(line);
    switch (parseChoice(line, 2)) {
        .pick => |n| if (n == 1) {
            try running(zh, "nvm uninstall <version>");
            const argv = [_][]const u8{ commands.program_name, "uninstall", picked };
            try commands.cmdUninstall(allocator, &argv, config);
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
