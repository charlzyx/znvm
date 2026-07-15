const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const util = @import("util.zig");
const version = @import("version.zig");
const ZnvmConfig = @import("config.zig").ZnvmConfig;

const stdout = util.stdout;
const stderr = util.stderr;

/// 通过检测 PATH 中实际使用的 node 路径来获取当前生效的 znvm 版本
fn getCurrentVersionFromPath(allocator: mem.Allocator, config: ZnvmConfig) !?[]u8 {
    // 从 PATH 环境变量中查找 node
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const path_env = env_map.get("PATH") orelse return null;

    var it = mem.splitScalar(u8, path_env, ':');
    while (it.next()) |dir| {
        if (dir.len == 0) continue;

        // 检查该目录下的 node 可执行文件
        const node_path = try fs.path.join(allocator, &.{ dir, "node" });
        defer allocator.free(node_path);

        // 检查文件是否存在且可执行
        fs.accessAbsolute(node_path, .{}) catch continue;

        // 获取真实路径（处理符号链接）
        const real_path = std.fs.realpathAlloc(allocator, node_path) catch continue;
        defer allocator.free(real_path);

        // 检查路径是否在 versions_dir 下（确保是前缀匹配）
        const versions_dir_with_sep = try std.fmt.allocPrint(allocator, "{s}/", .{config.versions_dir});
        defer allocator.free(versions_dir_with_sep);

        // 检查 real_path 是否以 versions_dir/ 开头
        if (!mem.startsWith(u8, real_path, versions_dir_with_sep)) continue;

        // 提取版本号，路径格式为: ~/.znvm/versions/v20.0.0/bin/node
        const after_versions = real_path[versions_dir_with_sep.len..];
        // 找到下一个 / 的位置
        if (mem.indexOfScalar(u8, after_versions, '/')) |end| {
            return try allocator.dupe(u8, after_versions[0..end]);
        }

        return null;
    }

    return null;
}

fn shellQuote(allocator: mem.Allocator, value: []const u8) ![]u8 {
    var quoted = std.ArrayList(u8){};
    errdefer quoted.deinit(allocator);

    try quoted.append(allocator, '\'');
    for (value) |char| {
        if (char == '\'') {
            try quoted.appendSlice(allocator, "'\\''");
        } else {
            try quoted.append(allocator, char);
        }
    }
    try quoted.append(allocator, '\'');
    return quoted.toOwnedSlice(allocator);
}

pub fn cmdEnv(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    _ = args;

    const root_dir = try shellQuote(allocator, config.root_dir);
    defer allocator.free(root_dir);
    const npm_prefix = try shellQuote(allocator, config.npm_prefix);
    defer allocator.free(npm_prefix);
    const npm_bin_path = try fs.path.join(allocator, &.{ config.npm_prefix, "bin" });
    defer allocator.free(npm_bin_path);
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();
    const current_path = env_map.get("PATH") orelse "";

    var path_list = std.ArrayList(u8){};
    defer path_list.deinit(allocator);
    try path_list.appendSlice(allocator, npm_bin_path);
    var path_it = mem.splitScalar(u8, current_path, ':');
    while (path_it.next()) |entry| {
        if (entry.len == 0 or mem.eql(u8, entry, npm_bin_path)) continue;
        try path_list.append(allocator, ':');
        try path_list.appendSlice(allocator, entry);
    }
    const path_value = try shellQuote(allocator, path_list.items);
    defer allocator.free(path_value);

    // The wrapper function
    const shell_script =
        \\# znvm shell setup
        \\export ZNVM_DIR={s}
        \\export NPM_CONFIG_PREFIX={s}
        \\export PATH={s}
        \\
        \\znvm() {{
        \\  if [ "$1" = "use" ]; then
        \\    local result
        \\    result=$(command znvm "$@")
        \\    local exit_code=$?
        \\    if [ $exit_code -eq 0 ]; then
        \\      eval "$result"
        \\    else
        \\      echo "$result"
        \\      return $exit_code
        \\    fi
        \\  else
        \\    command znvm "$@"
        \\  fi
        \\}}
        \\
        \\# Auto-use on shell startup: .nvmrc takes priority, fallback to default
        \\if [ -f ".nvmrc" ]; then
        \\  znvm use "$(cat .nvmrc | head -n 1 | tr -d '[:space:]')" >/dev/null 2>&1 || true
        \\elif [ -f "$ZNVM_DIR/default" ]; then
        \\  znvm use "$(cat "$ZNVM_DIR/default" | tr -d '[:space:]')" >/dev/null 2>&1 || true
        \\fi
    ;
    try stdout(shell_script, .{ root_dir, npm_prefix, path_value });
}

pub fn cmdUse(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    if (args.len < 3) {
        const cwd = try fs.cwd().realpathAlloc(allocator, ".");
        defer allocator.free(cwd);
        const nvmrc_path = try fs.path.join(allocator, &.{ cwd, ".nvmrc" });
        defer allocator.free(nvmrc_path);

        var target_version: []const u8 = "";

        const file = fs.openFileAbsolute(nvmrc_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                try stderr("Usage: znvm use <version>\n", .{});
                process.exit(1);
            }
            return err;
        };
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 1024);
        defer allocator.free(content);
        target_version = mem.trim(u8, content, " \t\n\r");
        if (target_version.len == 0) {
            try stderr(".nvmrc is empty\n", .{});
            process.exit(1);
        }
        try useVersion(allocator, target_version, config);
        return;
    }

    try useVersion(allocator, args[2], config);
}

fn useVersion(allocator: mem.Allocator, query: []const u8, config: ZnvmConfig) !void {
    // 1. Resolve query to installed version
    const installed = try version.getInstalledVersions(allocator, config);
    defer {
        for (installed) |v| allocator.free(v);
        allocator.free(installed);
    }

    const resolved = try version.resolveLocalVersion(allocator, installed, query);

    if (resolved == null) {
        try stderr("Version '{s}' not installed. Run 'znvm install {s}' first.\n", .{ query, query });
        process.exit(1);
    }

    const ver = resolved.?;
    const ver_path = try fs.path.join(allocator, &.{ config.versions_dir, ver });
    defer allocator.free(ver_path);
    const bin_path = try fs.path.join(allocator, &.{ ver_path, "bin" });
    defer allocator.free(bin_path);
    const npm_bin_path = try fs.path.join(allocator, &.{ config.npm_prefix, "bin" });
    defer allocator.free(npm_bin_path);
    const versions_dir_with_sep = try std.fmt.allocPrint(allocator, "{s}/", .{config.versions_dir});
    defer allocator.free(versions_dir_with_sep);

    // Check if bin/node exists
    const node_bin = try fs.path.join(allocator, &.{ bin_path, "node" });
    defer allocator.free(node_bin);
    fs.accessAbsolute(node_bin, .{}) catch {
        try stderr("Version '{s}' is installed but bin/node is missing.\n", .{ver});
        process.exit(1);
    };

    // Output shell commands to set PATH
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const current_path = env_map.get("PATH") orelse "";

    var new_path_list = std.ArrayList(u8){};
    defer new_path_list.deinit(allocator);

    // Shared global commands take priority over version-local legacy shims.
    try new_path_list.appendSlice(allocator, npm_bin_path);
    try new_path_list.append(allocator, ':');
    try new_path_list.appendSlice(allocator, bin_path);

    var it = mem.splitScalar(u8, current_path, ':');
    while (it.next()) |p| {
        if (p.len == 0) continue;
        if (mem.startsWith(u8, p, versions_dir_with_sep) or mem.eql(u8, p, npm_bin_path)) continue;

        try new_path_list.append(allocator, ':');
        try new_path_list.appendSlice(allocator, p);
    }

    const quoted_path = try shellQuote(allocator, new_path_list.items);
    defer allocator.free(quoted_path);
    const quoted_version = try shellQuote(allocator, ver);
    defer allocator.free(quoted_version);
    const quoted_npm_prefix = try shellQuote(allocator, config.npm_prefix);
    defer allocator.free(quoted_npm_prefix);

    try stdout("export PATH={s}\n", .{quoted_path});
    try stdout("export ZNVM_CURRENT={s}\n", .{quoted_version});
    try stdout("export NPM_CONFIG_PREFIX={s}\n", .{quoted_npm_prefix});

    try stderr("Using {s}\n", .{ver});
}

pub fn cmdInstall(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    if (args.len < 3) {
        try stderr("Usage: znvm install <version>\n", .{});
        process.exit(1);
    }
    const query = args[2];

    // 1. Resolve remote version
    const resolved = try version.resolveRemoteVersion(allocator, query, config);
    if (resolved == null) {
        try stderr("Could not resolve version '{s}'\n", .{query});
        process.exit(1);
    }
    const ver = resolved.?.version;
    const filename = resolved.?.filename;
    defer allocator.free(ver);
    defer allocator.free(filename);

    const install_path = try fs.path.join(allocator, &.{ config.versions_dir, ver });
    defer allocator.free(install_path);

    // Check if already installed
    if (fs.accessAbsolute(install_path, .{}) catch error.FileNotFound == error.FileNotFound) {
        // Proceed
    } else {
        try stderr("Version {s} is already installed.\n", .{ver});
        return;
    }

    try stderr("Installing {s} ({s})...\n", .{ ver, config.arch });

    // 2. Download
    const download_url = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ config.mirror, ver, filename });
    defer allocator.free(download_url);
    const tar_path = try fs.path.join(allocator, &.{ config.root_dir, filename });
    defer allocator.free(tar_path);

    // Ensure root dir exists
    fs.makeDirAbsolute(config.root_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    try version.downloadFile(allocator, download_url, tar_path);

    // 3. Extract
    try stderr("Extracting...\n", .{});
    fs.makeDirAbsolute(config.versions_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    fs.makeDirAbsolute(install_path) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const argv = &[_][]const u8{ "tar", "-xzf", tar_path, "-C", install_path, "--strip-components=1" };
    var child = process.Child.init(argv, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Inherit;

    const term = try child.spawnAndWait();
    if (term.Exited != 0) {
        try stderr("Extraction failed.\n", .{});
        // cleanup
        fs.deleteTreeAbsolute(install_path) catch {};
        process.exit(1);
    }

    // Cleanup tarball
    fs.deleteFileAbsolute(tar_path) catch {};

    try stderr("Installed {s}\n", .{ver});
}

pub fn cmdList(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    _ = args;
    const installed = try version.getInstalledVersions(allocator, config);
    defer {
        for (installed) |v| allocator.free(v);
        allocator.free(installed);
    }

    if (installed.len == 0) {
        try stdout("No versions installed.\n", .{});
        return;
    }

    // 通过检测 PATH 中实际使用的 node 路径来获取当前版本
    const current_ver = try getCurrentVersionFromPath(allocator, config);
    defer if (current_ver) |v| allocator.free(v);

    // Get default version
    const default_file = try fs.path.join(allocator, &.{ config.root_dir, "default" });
    defer allocator.free(default_file);

    var default_ver: ?[]const u8 = null;
    defer if (default_ver) |v| allocator.free(v);

    const default_file_handle = fs.openFileAbsolute(default_file, .{}) catch null;
    if (default_file_handle) |file| {
        defer file.close();
        const content = file.readToEndAlloc(allocator, 1024) catch null;
        if (content) |c| {
            defer allocator.free(c);
            const trimmed = mem.trim(u8, c, " \t\n\r");
            default_ver = try allocator.dupe(u8, trimmed);
        }
    }

    for (installed) |ver| {
        var is_current = false;
        var is_default = false;

        // Check current version
        if (current_ver) |c| {
            if (mem.eql(u8, c, ver)) {
                is_current = true;
            }
        }

        // Check default version
        if (default_ver) |d| {
            if (mem.eql(u8, d, ver)) {
                is_default = true;
            }
        }

        // Build markers string (fixed width: 6 chars "[*->]" or "      ")
        // [*] = default, [->] = current
        var markers_buf: [6]u8 = undefined;
        @memset(&markers_buf, ' ');
        if (is_current or is_default) {
            var pos: usize = 0;
            markers_buf[pos] = '[';
            pos += 1;
            if (is_default) {
                markers_buf[pos] = '*';
                pos += 1;
            }
            if (is_current) {
                @memcpy(markers_buf[pos .. pos + 2], "->");
                pos += 2;
            }
            markers_buf[pos] = ']';
        }

        try stdout("{s} {s}\n", .{ markers_buf, ver });
    }
}

pub fn cmdUninstall(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    if (args.len < 3) {
        try stderr("Usage: znvm uninstall <version>\n", .{});
        process.exit(1);
    }
    const query = args[2];

    const installed = try version.getInstalledVersions(allocator, config);
    defer {
        for (installed) |v| allocator.free(v);
        allocator.free(installed);
    }
    const resolved = try version.resolveLocalVersion(allocator, installed, query);

    if (resolved == null) {
        try stderr("Version '{s}' not installed.\n", .{query});
        process.exit(1);
    }

    const ver = resolved.?;
    const path = try fs.path.join(allocator, &.{ config.versions_dir, ver });
    defer allocator.free(path);

    try fs.deleteTreeAbsolute(path);
    try stderr("Uninstalled {s}\n", .{ver});
}

pub fn cmdDefault(allocator: mem.Allocator, args: []const []const u8, config: ZnvmConfig) !void {
    if (args.len < 3) {
        // Show current default
        const default_file = try fs.path.join(allocator, &.{ config.root_dir, "default" });
        defer allocator.free(default_file);

        const file = fs.openFileAbsolute(default_file, .{}) catch |err| {
            if (err == error.FileNotFound) {
                try stderr("No default version set.\n", .{});
                process.exit(1);
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024);
        defer allocator.free(content);
        const ver = mem.trim(u8, content, " \t\n\r");
        try stdout("{s}\n", .{ver});
        return;
    }

    const query = args[2];

    // Verify version is installed
    const installed = try version.getInstalledVersions(allocator, config);
    defer {
        for (installed) |v| allocator.free(v);
        allocator.free(installed);
    }
    const resolved = try version.resolveLocalVersion(allocator, installed, query);

    if (resolved == null) {
        try stderr("Version '{s}' not installed. Run 'znvm install {s}' first.\n", .{ query, query });
        process.exit(1);
    }

    const ver = resolved.?;

    // Write to default file
    const default_file = try fs.path.join(allocator, &.{ config.root_dir, "default" });
    defer allocator.free(default_file);

    const file = try fs.createFileAbsolute(default_file, .{});
    defer file.close();

    try file.writeAll(ver);
    try stderr("Set default version to {s}\n", .{ver});
}
