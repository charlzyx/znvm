//! Package root for `zig build test`, for the same reason as `exe_root.zig`.
comptime {
    _ = @import("src/tests.zig");
}
