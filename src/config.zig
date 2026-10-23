const std = @import("std");
const host = @import("host.zig");
const builtin = @import("builtin");
const process = std.process;
const fs = std.fs;
const mem = std.mem;

pub const ZnvmConfig = struct {
    /// Data root. `NVM_DIR` when it is set, otherwise `ZNVM_DIR`, otherwise `~/.nvm`.
    root_dir: []const u8,
    /// New Node installs (0.12 and later) go here: `$root/versions/node`.
    versions_dir: []const u8,
    /// Directories whose children may be `vX.Y.Z` installs, including legacy layouts.
    scan_dirs: []const []const u8,
    /// Directory roots used to recognize a managed Node `bin` on `PATH`.
    managed_roots: []const []const u8,
    /// Set only when `ZNVM_NPM_PREFIX` opts into one shared global prefix.
    /// Unset means each Node version keeps its own prefix, matching nvm.
    npm_prefix: ?[]const u8,
    mirror: []const u8,
    arch: []const u8,
    os: []const u8,
    allocator: mem.Allocator,

    pub fn deinit(self: ZnvmConfig) void {
        const allocator = self.allocator;
        allocator.free(self.root_dir);
        allocator.free(self.versions_dir);
        for (self.scan_dirs) |dir| allocator.free(dir);
        allocator.free(self.scan_dirs);
        for (self.managed_roots) |dir| allocator.free(dir);
        allocator.free(self.managed_roots);
        if (self.npm_prefix) |prefix| allocator.free(prefix);
        allocator.free(self.mirror);
    }
};

pub fn resolveNpmPrefix(allocator: mem.Allocator, configured: ?[]const u8) !?[]u8 {
    const prefix = configured orelse return null;
    if (prefix.len == 0) return null;
    if (!fs.path.isAbsolute(prefix) or mem.indexOfScalar(u8, prefix, ':') != null) {
        return error.InvalidNpmPrefix;
    }
    return try allocator.dupe(u8, prefix);
}

fn nonempty(value: ?[]const u8) ?[]const u8 {
    const text = value orelse return null;
    if (text.len == 0) return null;
    return text;
}

fn trimTrailingSlash(value: []const u8) []const u8 {
    if (value.len > 1 and value[value.len - 1] == '/') return value[0 .. value.len - 1];
    return value;
}

/// `NVM_DIR` wins so an existing nvm setup is the data directory.
/// `ZNVM_DIR` is used only when `NVM_DIR` is unset, which keeps older znvm
/// configs and isolated tests working.
pub fn resolveDataRoot(allocator: mem.Allocator, nvm_dir: ?[]const u8, znvm_dir: ?[]const u8, home: []const u8) ![]u8 {
    if (nonempty(nvm_dir)) |dir| return allocator.dupe(u8, trimTrailingSlash(dir));
    if (nonempty(znvm_dir)) |dir| return allocator.dupe(u8, trimTrailingSlash(dir));
    return fs.path.join(allocator, &.{ home, ".nvm" });
}

fn addOwned(allocator: mem.Allocator, list: *std.ArrayList([]const u8), path: []u8) !void {
    for (list.items) |existing| {
        if (mem.eql(u8, existing, path)) {
            allocator.free(path);
            return;
        }
    }
    try list.append(allocator, path);
}

pub fn getConfig(allocator: mem.Allocator) !ZnvmConfig {
    var env_map = try host.envMap(allocator);
    defer env_map.deinit();

    const home = env_map.get("HOME") orelse ".";
    const root_dir = try resolveDataRoot(allocator, env_map.get("NVM_DIR"), env_map.get("ZNVM_DIR"), home);
    errdefer allocator.free(root_dir);

    const versions_dir = try fs.path.join(allocator, &.{ root_dir, "versions", "node" });
    errdefer allocator.free(versions_dir);

    var scan : std.ArrayList([]const u8) = .empty;
    errdefer {
        for (scan.items) |dir| allocator.free(dir);
        scan.deinit(allocator);
    }
    var managed : std.ArrayList([]const u8) = .empty;
    errdefer {
        for (managed.items) |dir| allocator.free(dir);
        managed.deinit(allocator);
    }

    try addOwned(allocator, &scan, try allocator.dupe(u8, versions_dir));
    // znvm before the nvm layout stored tarballs directly in `$root/versions/vX`.
    try addOwned(allocator, &scan, try fs.path.join(allocator, &.{ root_dir, "versions" }));
    // nvm stores Node < 0.12 directly in `$NVM_DIR/vX`.
    try addOwned(allocator, &scan, try allocator.dupe(u8, root_dir));
    try addOwned(allocator, &managed, try allocator.dupe(u8, root_dir));

    const legacy_root = try fs.path.join(allocator, &.{ home, ".znvm" });
    defer allocator.free(legacy_root);
    if (!mem.eql(u8, legacy_root, root_dir)) {
        try addOwned(allocator, &scan, try fs.path.join(allocator, &.{ legacy_root, "versions", "node" }));
        try addOwned(allocator, &scan, try fs.path.join(allocator, &.{ legacy_root, "versions" }));
        try addOwned(allocator, &managed, try allocator.dupe(u8, legacy_root));
    }

    const npm_prefix = try resolveNpmPrefix(allocator, env_map.get("ZNVM_NPM_PREFIX"));
    errdefer if (npm_prefix) |prefix| allocator.free(prefix);

    const mirror_env = env_map.get("ZNVM_NODE_MIRROR") orelse env_map.get("NVM_NODEJS_ORG_MIRROR") orelse "https://npmmirror.com/mirrors/node";
    const mirror = try allocator.dupe(u8, mirror_env);
    errdefer allocator.free(mirror);

    const os = switch (builtin.os.tag) {
        .macos => "darwin",
        .linux => "linux",
        else => "unknown",
    };

    const arch = switch (builtin.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x64",
        else => "unknown",
    };

    return ZnvmConfig{
        .root_dir = root_dir,
        .versions_dir = versions_dir,
        .scan_dirs = try scan.toOwnedSlice(allocator),
        .managed_roots = try managed.toOwnedSlice(allocator),
        .npm_prefix = npm_prefix,
        .mirror = mirror,
        .os = os,
        .arch = arch,
        .allocator = allocator,
    };
}
