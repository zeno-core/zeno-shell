const std = @import("std");
const zeno = @import("zeno");
const schema = @import("schema.zig");
const scoreMod = @import("score.zig");

const dbMod = zeno.public;
const types = zeno.types;

pub const Suggestion = struct {
    cmd: []u8, // caller-owned after the call
    score: f64,
};

/// Returns the top N suggestions for a typed prefix.
/// Combines global and per-directory results, weighting directory entries 2x.
/// Caller must free each suggestion.cmd and the slice itself.
pub fn suggest(
    db: *dbMod.Database,
    allocator: std.mem.Allocator,
    query: []const u8,
    cwd: []const u8,
    maxResults: usize,
) ![]Suggestion {
    const nowMs = std.time.milliTimestamp();

    // HashMap for merge: cmd -> accumulated score
    var scores = std.StringHashMap(f64).init(allocator);
    defer {
        var it = scores.keyIterator();
        while (it.next()) |k| allocator.free(k.*);
        scores.deinit();
    }

    // Process global entries (weight 1x)
    {
        var gKeyBuf: [schema.MAX_KEY_LEN]u8 = undefined;
        const gPrefix = schema.globalQueryPrefix(&gKeyBuf, query);
        var globalResult = try db.scan_prefix(allocator, gPrefix);
        defer globalResult.deinit();

        for (globalResult.entries.items) |entry| {
            const cmd = schema.extractCmdFromGlobalKey(entry.key);
            if (cmd.len == 0) continue;
            if (entry.value.* == .string) {
                if (schema.decodeEntry(entry.value.string)) |e| {
                    const s = scoreMod.calculate(e, nowMs);
                    const cmdOwned = try allocator.dupe(u8, cmd);
                    const gop = try scores.getOrPut(cmdOwned);
                    if (gop.found_existing) {
                        gop.value_ptr.* += s;
                        allocator.free(cmdOwned);
                    } else {
                        gop.value_ptr.* = s;
                    }
                }
            }
        }
    }

    // Process per-directory entries (weight 2x — local context is more relevant)
    {
        var dKeyBuf: [schema.MAX_KEY_LEN]u8 = undefined;
        const dPrefix = schema.dirQueryPrefix(&dKeyBuf, cwd, query);
        var dirResult = try db.scan_prefix(allocator, dPrefix);
        defer dirResult.deinit();

        for (dirResult.entries.items) |entry| {
            const cmd = schema.extractCmdFromDirKey(entry.key, cwd);
            if (cmd.len == 0) continue;
            if (entry.value.* == .string) {
                if (schema.decodeEntry(entry.value.string)) |e| {
                    const s = scoreMod.calculate(e, nowMs) * 2.0;
                    const cmdOwned = try allocator.dupe(u8, cmd);
                    const gop = try scores.getOrPut(cmdOwned);
                    if (gop.found_existing) {
                        gop.value_ptr.* += s;
                        allocator.free(cmdOwned);
                    } else {
                        gop.value_ptr.* = s;
                    }
                }
            }
        }
    }

    // Collect and sort by score descending
    const total = scores.count();
    const candidates = try allocator.alloc(Suggestion, total);
    defer allocator.free(candidates);

    var i: usize = 0;
    var it = scores.iterator();
    while (it.next()) |kv| {
        candidates[i] = .{
            .cmd = @constCast(kv.key_ptr.*),
            .score = kv.value_ptr.*,
        };
        i += 1;
    }

    std.mem.sort(Suggestion, candidates, {}, struct {
        fn lessThan(_: void, a: Suggestion, b: Suggestion) bool {
            return a.score > b.score;
        }
    }.lessThan);

    const n = @min(maxResults, candidates.len);
    const result = try allocator.alloc(Suggestion, n);
    var initialized: usize = 0;
    errdefer {
        for (result[0..initialized]) |s| allocator.free(s.cmd);
        allocator.free(result);
    }

    for (result, 0..) |*dst, idx| {
        dst.cmd = try allocator.dupe(u8, candidates[idx].cmd);
        dst.score = candidates[idx].score;
        initialized += 1;
    }

    return result;
}
