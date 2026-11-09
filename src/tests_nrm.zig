const std = @import("std");
const testing = std.testing;
const registry = @import("registry.zig");

test "nrm dash padding grows with column width" {
    try testing.expectEqual(@as(usize, 4), registry.geneDashLine("npm", 6));
    try testing.expect(registry.geneDashLine("npm", 6) >= 2);
    try testing.expectEqual(@as(usize, 5), registry.geneDashLine("taobao", 10));
}
