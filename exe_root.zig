//! Package root for the znvm binary.
//! The root file has to live next to `skills/` so `@embedFile` can include
//! `skills/znvm/SKILL.md`. A root under `src/` would reject that path.
pub fn main() !void {
    return @import("src/main.zig").main();
}
