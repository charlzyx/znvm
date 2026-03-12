const std = @import("std");
const builtin = @import("builtin");
const process = std.process;
const fs = std.fs;
const mem = std.mem;

pub const ZnvmConfig = struct {
    root_dir: []const u8,
    versions_dir: []const u8,
    mirror: []const u8,
    arch: []const u8,
    os: []const u8,
    allocator: mem.Allocator,

    pub fn deinit(self: ZnvmConfig) void {
        self.allocator.free(self.root_dir);
        self.allocator.free(self.versions_dir);
        self.allocator.free(self.mirror);
        // arch/os are string literals usually
    }
};

pub fn getConfig(allocator: mem.Allocator) !ZnvmConfig {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    const home = env_map.get("HOME") orelse ".";
    const root_env = env_map.get("ZNVM_DIR");
    
    // If ZNVM_DIR is set, use it. Otherwise join home + .znvm
    const root_dir = if (root_env) |r| try allocator.dupe(u8, r) else try fs.path.join(allocator, &.{ home, ".znvm" });
    errdefer allocator.free(root_dir);
    
    const versions_dir = try fs.path.join(allocator, &.{ root_dir, "versions" });
    errdefer allocator.free(versions_dir);
    
    const mirror_env = env_map.get("ZNVM_NODE_MIRROR") orelse "https://npmmirror.com/mirrors/node";
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
        .mirror = mirror,
        .os = os,
        .arch = arch,
        .allocator = allocator,
    };
}
