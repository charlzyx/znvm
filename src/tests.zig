const std = @import("std");
const mem = std.mem;
const testing = std.testing;

// Import modules to test
const version = @import("version.zig");
const config = @import("config.zig");
const util = @import("util.zig");
const registry = @import("registry.zig");
const agent = @import("agent.zig");

test "registry module is linked" {
    try testing.expect(registry.china_registry.len > 0);
}

test "agent module is linked" {
    try testing.expect(agent.truthy("yes"));
    try testing.expect(!agent.truthy("0"));
}

// Test utilities
fn createTestAllocator() std.mem.Allocator {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    return gpa.allocator();
}

// ============================================
// Version parsing logic tests
// ============================================

test "resolveLocalVersion: exact match with v prefix" {
    const allocator = std.testing.allocator;
    const installed = &[_][]const u8{ "v18.0.0", "v20.0.0", "v22.0.0" };

    const result = try version.resolveLocalVersion(allocator, installed, "v20.0.0");
    try testing.expectEqualSlices(u8, "v20.0.0", result.?);
}

test "resolveLocalVersion: without v prefix" {
    const allocator = std.testing.allocator;
    const installed = &[_][]const u8{ "v18.0.0", "v20.0.0", "v22.0.0" };

    const result = try version.resolveLocalVersion(allocator, installed, "20.0.0");
    try testing.expectEqualSlices(u8, "v20.0.0", result.?);
}

test "resolveLocalVersion: major version prefix match" {
    const allocator = std.testing.allocator;
    const installed = &[_][]const u8{ "v18.0.0", "v20.0.0", "v20.5.0", "v22.0.0" };

    const result = try version.resolveLocalVersion(allocator, installed, "20");
    try testing.expect(result != null);
    try testing.expect(mem.startsWith(u8, result.?, "v20"));
}

test "resolveLocalVersion: major query respects segment boundary" {
    const allocator = std.testing.allocator;
    const installed = &[_][]const u8{ "v2.4.0", "v20.1.0", "v22.0.0" };

    const result = try version.resolveLocalVersion(allocator, installed, "2");
    try testing.expectEqualSlices(u8, "v2.4.0", result.?);
}

test "resolveLocalVersion: selects latest matching installed version" {
    const allocator = std.testing.allocator;
    const installed = &[_][]const u8{ "v20.5.0", "v22.0.0", "v20.0.0" };

    const result = try version.resolveLocalVersion(allocator, installed, "20");
    try testing.expectEqualSlices(u8, "v20.5.0", result.?);
}

test "resolveLocalVersion: version not found" {
    const allocator = std.testing.allocator;
    const installed = &[_][]const u8{ "v18.0.0", "v20.0.0" };

    const result = try version.resolveLocalVersion(allocator, installed, "v25.0.0");
    try testing.expectEqual(@as(?[]const u8, null), result);
}

test "resolveLocalVersion: empty installed list" {
    const allocator = std.testing.allocator;
    const installed = &[_][]const u8{};

    const result = try version.resolveLocalVersion(allocator, installed, "20.0.0");
    try testing.expectEqual(@as(?[]const u8, null), result);
}

// ============================================
// String manipulation tests
// ============================================

test "string: startsWith v prefix" {
    try testing.expect(mem.startsWith(u8, "v20.0.0", "v"));
    try testing.expect(!mem.startsWith(u8, "20.0.0", "v"));
}

test "string: trim whitespace" {
    const str = "  v20.0.0\n";
    const trimmed = mem.trim(u8, str, " \t\n\r");
    try testing.expectEqualSlices(u8, "v20.0.0", trimmed);
}

test "string: indexOf check" {
    const path = "/home/user/.znvm/versions/v20.0.0/bin/node";
    const versions_dir = "/home/user/.znvm/versions";

    const idx = mem.indexOf(u8, path, versions_dir);
    try testing.expect(idx != null);
}

test "string: eql comparison" {
    try testing.expect(mem.eql(u8, "v20.0.0", "v20.0.0"));
    try testing.expect(!mem.eql(u8, "v20.0.0", "v20.0.1"));
}

// ============================================
// Semantic Version tests
// ============================================

test "semantic version: parse valid version" {
    const result = std.SemanticVersion.parse("20.0.0");
    try testing.expect(result != error.InvalidVersion);
}

test "semantic version: parse with prerelease" {
    const result = std.SemanticVersion.parse("20.0.0-rc.1");
    try testing.expect(result != error.InvalidVersion);
}

test "semantic version: comparison" {
    const v1 = try std.SemanticVersion.parse("20.0.0");
    const v2 = try std.SemanticVersion.parse("20.0.1");
    const v3 = try std.SemanticVersion.parse("18.0.0");

    // v2 > v1
    try testing.expect(v1.order(v2) == .lt);
    // v1 < v2
    try testing.expect(v2.order(v1) == .gt);
    // v1 > v3
    try testing.expect(v3.order(v1) == .lt);
}

test "semantic version: equal comparison" {
    const v1 = try std.SemanticVersion.parse("20.0.0");
    const v2 = try std.SemanticVersion.parse("20.0.0");

    try testing.expect(v1.order(v2) == .eq);
}

// ============================================
// Path handling tests
// ============================================

test "path: join multiple segments" {
    const allocator = std.testing.allocator;
    const path = try std.fs.path.join(allocator, &.{ "/home", "user", ".znvm" });
    defer allocator.free(path);

    try testing.expect(mem.endsWith(u8, path, ".znvm"));
}

test "path: extract version from PATH" {
    const path = "/home/user/.znvm/versions/v20.0.0/bin";
    const versions_dir = "/home/user/.znvm/versions";

    const start = mem.indexOf(u8, path, versions_dir);
    try testing.expect(start != null);

    const after_versions = path[start.? + versions_dir.len + 1 ..];
    const end = mem.indexOfScalar(u8, after_versions, '/');

    if (end) |e| {
        const version_str = after_versions[0..e];
        try testing.expectEqualSlices(u8, "v20.0.0", version_str);
    }
}

// ============================================
// List sorting tests
// ============================================

test "version list: sorting by semantic version" {
    const allocator = std.testing.allocator;
    var versions = std.ArrayList([]const u8){};
    defer versions.deinit(allocator);

    try versions.append(allocator, "v22.0.0");
    try versions.append(allocator, "v18.0.0");
    try versions.append(allocator, "v20.0.0");

    const Sorter = struct {
        pub fn less(context: void, lhs: []const u8, rhs: []const u8) bool {
            _ = context;
            const v1 = std.SemanticVersion.parse(lhs[1..]) catch return false;
            const v2 = std.SemanticVersion.parse(rhs[1..]) catch return true;
            return v1.order(v2) == .lt;
        }
    };

    mem.sort([]const u8, versions.items, {}, Sorter.less);

    try testing.expectEqualSlices(u8, "v18.0.0", versions.items[0]);
    try testing.expectEqualSlices(u8, "v20.0.0", versions.items[1]);
    try testing.expectEqualSlices(u8, "v22.0.0", versions.items[2]);
}

test "npm prefix: empty value keeps nvm's per-version prefix" {
    const prefix = try config.resolveNpmPrefix(std.testing.allocator, "");
    try testing.expect(prefix == null);
}

test "npm prefix: accepts absolute path" {
    const allocator = std.testing.allocator;
    const prefix = try config.resolveNpmPrefix(allocator, "/tmp/shared npm");
    defer allocator.free(prefix.?);

    try testing.expectEqualSlices(u8, "/tmp/shared npm", prefix.?);
}

test "npm prefix: rejects relative and PATH-separated values" {
    const allocator = std.testing.allocator;
    try testing.expectError(error.InvalidNpmPrefix, config.resolveNpmPrefix(allocator, "relative"));
    try testing.expectError(error.InvalidNpmPrefix, config.resolveNpmPrefix(allocator, "/tmp/one:/tmp/two"));
}

test "data root: NVM_DIR wins over ZNVM_DIR and the default is ~/.nvm" {
    const allocator = std.testing.allocator;
    const from_nvm = try config.resolveDataRoot(allocator, "/tmp/nvm", "/tmp/znvm", "/home/user");
    defer allocator.free(from_nvm);
    try testing.expectEqualSlices(u8, "/tmp/nvm", from_nvm);

    const from_znvm = try config.resolveDataRoot(allocator, null, "/tmp/znvm", "/home/user");
    defer allocator.free(from_znvm);
    try testing.expectEqualSlices(u8, "/tmp/znvm", from_znvm);

    const from_home = try config.resolveDataRoot(allocator, "", null, "/home/user");
    defer allocator.free(from_home);
    try testing.expectEqualSlices(u8, "/home/user/.nvm", from_home);
}

test "old node layout: versions before 0.12 live directly in NVM_DIR" {
    try testing.expect(version.isOldNodeLayout("v0.10.48"));
    try testing.expect(!version.isOldNodeLayout("v0.12.0"));
    try testing.expect(!version.isOldNodeLayout("v22.14.0"));
}

test "parseIndex: version strings stay valid after the response buffer is reused" {
    const allocator = testing.allocator;
    const raw =
        \\[{"version":"v22.14.0","files":["linux-x64"],"lts":false},{"version":"v20.19.0","files":["linux-x64"],"lts":"Iron"}]
    ;
    const body = try allocator.dupe(u8, raw);
    defer allocator.free(body);

    const parsed = try version.parseIndex(allocator, body);
    defer parsed.deinit();
    @memset(body, 0);

    const result = version.resolveRemoteEntry(parsed.value, "22.14.0", "linux-x64");
    try testing.expect(result != null);
    try testing.expectEqualSlices(u8, "v22.14.0", result.?.version);
    try testing.expectEqualSlices(u8, "linux-x64", result.?.files[0]);
}

test "resolveRemoteEntry: short version selects latest release line" {
    const files = &[_][]const u8{"osx-arm64-tar"};
    const entries = &[_]version.NodeEntry{
        .{ .version = "v20.1.0", .files = files },
        .{ .version = "v22.0.0", .files = files },
        .{ .version = "v20.12.2", .files = files },
    };

    const result = version.resolveRemoteEntry(entries, "20", "osx-arm64-tar");
    try testing.expect(result != null);
    try testing.expectEqualSlices(u8, "v20.12.2", result.?.version);
}

test "resolveRemoteEntry: short version respects segment boundary" {
    const files = &[_][]const u8{"linux-x64"};
    const entries = &[_]version.NodeEntry{
        .{ .version = "v2.5.0", .files = files },
        .{ .version = "v20.0.0", .files = files },
        .{ .version = "v22.0.0", .files = files },
    };

    const result = version.resolveRemoteEntry(entries, "2", "linux-x64");
    try testing.expect(result != null);
    try testing.expectEqualSlices(u8, "v2.5.0", result.?.version);
}

test "resolveRemoteArtifact: Apple Silicon falls back to x64" {
    const x64_files = &[_][]const u8{"osx-x64-tar"};
    const entries = &[_]version.NodeEntry{
        .{ .version = "v12.22.12", .files = x64_files },
        .{ .version = "v12.22.11", .files = x64_files },
    };

    const result = version.resolveRemoteArtifact(entries, "12", "darwin", "arm64");
    try testing.expect(result != null);
    try testing.expectEqualSlices(u8, "v12.22.12", result.?.entry.version);
    try testing.expectEqualSlices(u8, "x64", result.?.arch);
}

test "resolveRemoteArtifact: Apple Silicon prefers native arm64" {
    const both_files = &[_][]const u8{ "osx-arm64-tar", "osx-x64-tar" };
    const entries = &[_]version.NodeEntry{
        .{ .version = "v20.12.2", .files = both_files },
    };

    const result = version.resolveRemoteArtifact(entries, "20", "darwin", "arm64");
    try testing.expect(result != null);
    try testing.expectEqualSlices(u8, "arm64", result.?.arch);
}

// ============================================
// URL and format tests
// ============================================

test "url: format download URL correctly" {
    const allocator = std.testing.allocator;
    const mirror = "https://npmmirror.com/mirrors/node";
    const version_str = "v20.0.0";
    const filename = "node-v20.0.0-darwin-arm64.tar.gz";

    const url = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ mirror, version_str, filename });
    defer allocator.free(url);

    try testing.expect(mem.startsWith(u8, url, "https://npmmirror.com"));
    try testing.expect(mem.endsWith(u8, url, "tar.gz"));
}

test "filename: format correctly with os and arch" {
    const allocator = std.testing.allocator;
    const version_str = "v20.0.0";
    const os = "darwin";
    const arch = "arm64";

    const filename = try std.fmt.allocPrint(allocator, "node-{s}-{s}-{s}.tar.gz", .{ version_str, os, arch });
    defer allocator.free(filename);

    try testing.expect(mem.startsWith(u8, filename, "node-"));
    try testing.expect(mem.indexOf(u8, filename, "darwin") != null);
    try testing.expect(mem.indexOf(u8, filename, "arm64") != null);
}

// ============================================
// Edge case tests
// ============================================

test "edge case: single version in list" {
    const allocator = std.testing.allocator;
    const installed = &[_][]const u8{"v20.0.0"};

    const result = try version.resolveLocalVersion(allocator, installed, "20");
    try testing.expect(result != null);
}

test "edge case: version with leading zeros" {
    // Zig's SemanticVersion doesn't allow leading zeros (standard SemVer behavior)
    // So we just test that it properly rejects them
    const result = std.SemanticVersion.parse("020.0.0");
    try testing.expect(result == error.InvalidVersion);
}

test "edge case: query with letters" {
    const allocator = std.testing.allocator;
    const installed = &[_][]const u8{ "v18.0.0", "v20.0.0-rc.1" };

    const result = try version.resolveLocalVersion(allocator, installed, "rc");
    // Should not match anything (rc is just a prefix search)
    try testing.expect(result == null or mem.indexOf(u8, result.?, "rc") == null);
}

test "parseVersionQuery: node, lts, and numeric prefixes" {
    const node_query = version.parseVersionQuery("node", null);
    try testing.expect(node_query.special == .latest);

    const lts_query = version.parseVersionQuery("lts/*", null);
    try testing.expectEqualStrings("*", lts_query.lts.?);

    const named = version.parseVersionQuery("20", "iron");
    try testing.expectEqualStrings("iron", named.lts.?);
    try testing.expectEqualStrings("20", named.prefix);

    const current_query = version.parseVersionQuery("current", null);
    try testing.expect(current_query.special == .current);
}

test "looksLikeVersion: numbers are versions and filenames are not" {
    try testing.expect(version.looksLikeVersion("20"));
    try testing.expect(version.looksLikeVersion("v20.11.0"));
    try testing.expect(version.looksLikeVersion("20.11.1-rc.1"));
    try testing.expect(version.looksLikeVersion("node"));
    try testing.expect(version.looksLikeVersion("lts/iron"));
    try testing.expect(!version.looksLikeVersion("app.js"));
    try testing.expect(!version.looksLikeVersion("npm"));
    try testing.expect(!version.looksLikeVersion("--version"));
}

test "parseNvmrc: strips comments and ignores key-value lines" {
    const spec = version.parseNvmrc("\n# comment\nengine=node\n  20.11 # pin\n");
    try testing.expectEqualStrings("20.11", spec.?);
    try testing.expect(version.parseNvmrc("# only a comment\n") == null);
    try testing.expect(version.parseNvmrc("20\n22\n") == null);
}

test "resolveRemoteEntry: lts star skips non-LTS and current is not latest" {
    const files = &[_][]const u8{"linux-x64"};
    const entries = &[_]version.NodeEntry{
        .{ .version = "v20.11.0", .files = files, .lts = .{ .string = "Iron" } },
        .{ .version = "v22.14.0", .files = files, .lts = .{ .string = "Jod" } },
        .{ .version = "v23.1.0", .files = files, .lts = .{ .bool = false } },
    };

    const latest_lts = version.resolveRemoteEntry(entries, "lts/*", "linux-x64");
    try testing.expectEqualStrings("v22.14.0", latest_lts.?.version);

    const iron = version.resolveRemoteEntry(entries, "lts/iron", "linux-x64");
    try testing.expectEqualStrings("v20.11.0", iron.?.version);

    try testing.expect(version.resolveRemoteEntry(entries, "current", "linux-x64") == null);
}

test "findExactInstalled and latestInstalled" {
    const installed = &[_][]const u8{ "v20.0.0", "v20.11.1", "v22.0.0" };
    try testing.expectEqualStrings("v20.11.1", version.findExactInstalled(installed, "20.11.1").?);
    try testing.expect(version.findExactInstalled(installed, "20") == null);
    try testing.expectEqualStrings("v22.0.0", version.latestInstalled(installed, "").?);
    try testing.expectEqualStrings("v20.11.1", version.latestInstalled(installed, "20").?);
}
