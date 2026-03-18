const std = @import("std");
const schema = @import("schema.zig");

/// Computes the ranking score for an entry.
/// score = count × decay(ageHours)
/// More recent and more frequent entries get higher scores.
pub fn calculate(entry: schema.Entry, nowMs: i64) f64 {
    const count: f64 = @floatFromInt(entry.count);
    const ageMs = @max(0, nowMs - entry.lastMs);
    const ageHours: f64 = @as(f64, @floatFromInt(ageMs)) / 3_600_000.0;
    const decay = 1.0 / (1.0 + std.math.log2(ageHours + 1.0));
    return count * decay;
}

test "score decreases with age" {
    const now = std.time.milliTimestamp();
    const scoreRecent = calculate(.{ .count = 10, .lastMs = now }, now);
    const scoreOld = calculate(.{ .count = 10, .lastMs = 0 }, now);
    try std.testing.expect(scoreRecent > scoreOld);
}
