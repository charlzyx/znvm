const std = @import("std");
const mem = std.mem;
const testing = std.testing;

// Import modules to test
const version = @import("version.zig");
const config = @import("config.zig");
const util = @import("util.zig");

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
