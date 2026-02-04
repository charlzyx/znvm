const std = @import("std");
const process = std.process;
const json = std.json;
const SemVer = std.SemanticVersion;

const NodeEntry = struct {
    version: []const u8,
    date: []const u8,
    files: []const []const u8,
    npm: ?[]const u8 = null,
    v8: ?[]const u8 = null,
    uv: ?[]const u8 = null,
    zlib: ?[]const u8 = null,
    openssl: ?[]const u8 = null,
    modules: ?[]const u8 = null,
    lts: json.Value, // boolean or string
    security: bool,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("用法: {s} <command> [args...]\nUsage: {s} <command> [args...]\n", .{ args[0], args[0] });
        std.debug.print("命令 / Commands:\n", .{});
        std.debug.print("  resolve <version>           从远程 index.json 解析最佳版本 / Resolve best version from remote index.json\n", .{});
        std.debug.print("  semver compare <v1> <v2>    比较两个版本号 (-1/0/1) / Compare two versions\n", .{});
        std.debug.print("  semver match <query>        从 stdin 版本列表匹配最佳版本 / Match best version from stdin list\n", .{});
        process.exit(1);
    }

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "resolve")) {
        if (args.len < 3) {
            std.debug.print("错误: 缺少版本参数 / Error: Missing version argument\n", .{});
            process.exit(1);
        }
        try resolveVersion(allocator, args[2]);
    } else if (std.mem.eql(u8, cmd, "semver")) {
        if (args.len < 3) {
            std.debug.print("错误: 缺少 semver 子命令 / Error: Missing semver subcommand\n", .{});
            process.exit(1);
        }
        const semver_cmd = args[2];
        if (std.mem.eql(u8, semver_cmd, "compare")) {
            if (args.len < 5) {
                std.debug.print("错误: semver compare 需要两个版本参数 / Error: semver compare requires two version arguments\n", .{});
                process.exit(1);
            }
            try semverCompare(args[3], args[4]);
        } else if (std.mem.eql(u8, semver_cmd, "match")) {
            if (args.len < 4) {
                std.debug.print("错误: 缺少查询版本参数 / Error: Missing query version argument\n", .{});
                process.exit(1);
            }
            try semverMatch(allocator, args[3]);
        } else {
            std.debug.print("未知 semver 子命令: {s} / Unknown semver subcommand: {s}\n", .{ semver_cmd, semver_cmd });
            process.exit(1);
        }
    } else {
        std.debug.print("未知命令: {s} / Unknown command: {s}\n", .{ cmd, cmd });
        process.exit(1);
    }
}

fn resolveVersion(allocator: std.mem.Allocator, query: []const u8) !void {
    // 1. Read index.json from Stdin
    const stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };

    var body_list = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer body_list.deinit(allocator);

    var temp_buf: [4096]u8 = undefined;
    while (true) {
        const n = try stdin_file.read(&temp_buf);
        if (n == 0) break;
        try body_list.appendSlice(allocator, temp_buf[0..n]);
    }

    // 2. Parse JSON
    const parsed = json.parseFromSlice([]NodeEntry, allocator, body_list.items, .{ .ignore_unknown_fields = true }) catch |err| {
        std.debug.print("JSON 解析错误: {} / Error parsing JSON: {}\n", .{ err, err });
        process.exit(1);
    };
    defer parsed.deinit();

    // 3. Find match
    const entries = parsed.value;
    var best_match: ?SemVer = null;
    var best_ver_str: []const u8 = "";
    var best_arch: []const u8 = "";

    // Detect current OS/Arch
    const builtin = @import("builtin");
    const current_arch = builtin.cpu.arch;
    const current_os = builtin.os.tag;

    // Target suffix in 'files' list
    // macOS: 'osx'
    // Linux: 'linux'

    const os_prefix = switch (current_os) {
        .macos => "osx",
        .linux => "linux",
        else => {
            std.debug.print("错误: 不支持的操作系统: {} / Error: Unsupported OS: {}\n", .{ current_os, current_os });
            process.exit(1);
        },
    };

    const is_arm64 = current_arch == .aarch64;

    // Normalize query: remove 'v' prefix
    var clean_query = std.mem.trim(u8, query, " \t\n\r");
    if (std.mem.startsWith(u8, clean_query, "v")) {
        clean_query = clean_query[1..];
    }

    for (entries) |entry| {
        // entry.version is like "v23.6.0"
        if (entry.version.len < 2) continue;
        const ver_str = entry.version[1..]; // remove 'v'

        const semver = SemVer.parse(ver_str) catch continue;

        // Check availability
        var has_arm64 = false;
        var has_x64 = false;

        // Construct target strings dynamically
        // e.g. "osx-arm64-tar", "linux-x64-tar"

        for (entry.files) |f| {
            // We need to check if 'f' matches "{os_prefix}-arm64-tar" or "{os_prefix}-x64-tar"
            // For macOS, entries are like "osx-x64-tar", "osx-x64-pkg". We want "tar".
            // For Linux, entries are like "linux-x64", "linux-arm64". No "tar" suffix in the list.

            if (std.mem.startsWith(u8, f, os_prefix)) {
                if (current_os == .macos) {
                    if (std.mem.indexOf(u8, f, "arm64-tar") != null) has_arm64 = true;
                    if (std.mem.indexOf(u8, f, "x64-tar") != null) has_x64 = true;
                } else {
                    // Linux
                    // Ensure we don't match substrings incorrectly, but "linux-x64" is distinct enough.
                    // We check if it contains the arch.
                    if (std.mem.indexOf(u8, f, "arm64") != null) has_arm64 = true;
                    if (std.mem.indexOf(u8, f, "x64") != null) has_x64 = true;
                }
            }
        }

        // Determine compatible arch for this version
        var matched_arch: ?[]const u8 = null;
        if (is_arm64) {
            if (has_arm64) {
                matched_arch = "arm64";
            } else if (has_x64) {
                matched_arch = "x64"; // Rosetta fallback
            }
        } else {
            // x64
            if (has_x64) {
                matched_arch = "x64";
            }
        }

        if (matched_arch == null) continue; // Skip versions not available for this OS/Arch

        // Check if matches query
        var matches = false;
        if (std.mem.eql(u8, clean_query, "lts") or std.mem.startsWith(u8, clean_query, "lts/")) {
            switch (entry.lts) {
                .string => |s| {
                    if (std.mem.eql(u8, clean_query, "lts")) {
                        matches = true;
                    } else {
                        // "lts/argon" -> "argon"
                        const target_codename = clean_query[4..];
                        if (std.ascii.eqlIgnoreCase(s, target_codename)) {
                            matches = true;
                        }
                    }
                },
                .bool => |b| {
                    if (b and std.mem.eql(u8, clean_query, "lts")) {
                        matches = true;
                    }
                },
                else => {},
            }
        } else if (std.mem.eql(u8, clean_query, "latest") or std.mem.eql(u8, clean_query, "node")) {
            matches = true;
        } else {
            // Prefix match
            if (std.mem.startsWith(u8, ver_str, clean_query)) {
                if (ver_str.len == clean_query.len) {
                    matches = true;
                } else if (ver_str[clean_query.len] == '.') {
                    matches = true;
                }
            }
        }

        if (matches) {
            if (best_match == null) {
                best_match = semver;
                best_ver_str = entry.version;
                best_arch = matched_arch.?;
            } else {
                if (semver.order(best_match.?) == .gt) {
                    best_match = semver;
                    best_ver_str = entry.version;
                    best_arch = matched_arch.?;
                }
            }
        }
    }

    if (best_match) |_| {
        const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        const msg = try std.fmt.allocPrint(allocator, "{s} {s}\n", .{ best_ver_str, best_arch });
        defer allocator.free(msg);
        try stdout_file.writeAll(msg);
    } else {
        std.debug.print("错误: 未找到与 '{s}' 匹配的版本 / Error: No version found for query '{s}'\n", .{ query, query });
        process.exit(1);
    }
}

// SemVer compare: compare two versions
// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
fn semverCompare(v1: []const u8, v2: []const u8) !void {
    // Normalize versions (remove 'v' prefix)
    const ver1 = std.mem.trim(u8, v1, " \t\n\rv");
    const ver2 = std.mem.trim(u8, v2, " \t\n\rv");

    const semver1 = SemVer.parse(ver1) catch {
        std.debug.print("错误: 无效的版本号 '{s}' / Error: Invalid version '{s}'\n", .{ v1, v1 });
        process.exit(1);
    };
    const semver2 = SemVer.parse(ver2) catch {
        std.debug.print("错误: 无效的版本号 '{s}' / Error: Invalid version '{s}'\n", .{ v2, v2 });
        process.exit(1);
    };

    const result = semver1.order(semver2);
    const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    const out = switch (result) {
        .lt => "-1",
        .eq => "0",
        .gt => "1",
    };
    try stdout_file.writeAll(out);
    try stdout_file.writeAll("\n");
}

// SemVer match: match query against a list of versions from stdin
// Input: newline-separated version list from stdin
// Output: best matching version
fn semverMatch(allocator: std.mem.Allocator, query: []const u8) !void {
    const stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };

    // Read all versions from stdin
    var body_list = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer body_list.deinit(allocator);

    var temp_buf: [4096]u8 = undefined;
    while (true) {
        const n = try stdin_file.read(&temp_buf);
        if (n == 0) break;
        try body_list.appendSlice(allocator, temp_buf[0..n]);
    }

    // Normalize query
    var clean_query = std.mem.trim(u8, query, " \t\n\r");
    if (std.mem.startsWith(u8, clean_query, "v")) {
        clean_query = clean_query[1..];
    }

    var best_match: ?SemVer = null;
    var best_ver_str: []const u8 = "";

    var lines = std.mem.splitScalar(u8, body_list.items, '\n');
    while (lines.next()) |line| {
        const version_str = std.mem.trim(u8, line, " \t\n\r");
        if (version_str.len < 1) continue;

        const ver_without_v = if (std.mem.startsWith(u8, version_str, "v"))
            version_str[1..]
        else
            version_str;

        const semver = SemVer.parse(ver_without_v) catch continue;

        var matches = false;
        if (std.mem.eql(u8, clean_query, "latest") or std.mem.eql(u8, clean_query, "node")) {
            matches = true;
        } else {
            if (std.mem.startsWith(u8, ver_without_v, clean_query)) {
                if (ver_without_v.len == clean_query.len) {
                    matches = true;
                } else if (ver_without_v[clean_query.len] == '.') {
                    matches = true;
                }
            }
        }

        if (matches) {
            if (best_match == null) {
                best_match = semver;
                best_ver_str = version_str;
            } else {
                if (semver.order(best_match.?) == .gt) {
                    best_match = semver;
                    best_ver_str = version_str;
                }
            }
        }
    }

    if (best_match) |_| {
        const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        try stdout_file.writeAll(best_ver_str);
        try stdout_file.writeAll("\n");
    }
    // Exit silently if no match
}
