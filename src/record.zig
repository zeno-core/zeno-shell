const std = @import("std");
const zeno = @import("zeno");
const schema = @import("schema.zig");

const dbMod = zeno.public;
const types = zeno.types;
const Allocator = std.mem.Allocator;
const Database = dbMod.Database;

/// Opens the index at the given path.
///
/// Automatically derives WAL and snapshot paths from indexPath.
pub fn openIndex(allocator: Allocator, indexPath: []const u8) !*Database {
    const walPath = try std.fmt.allocPrint(allocator, "{s}.wal", .{indexPath});
    defer allocator.free(walPath);

    const snapPath = try std.fmt.allocPrint(allocator, "{s}.snap", .{indexPath});
    defer allocator.free(snapPath);

    return dbMod.open(allocator, .{
        .wal_path = walPath,
        .snapshot_path = snapPath,
        .fsync_mode = .batched_async,
        .metrics = types.MetricsConfig{ .mode = .disabled },
    });
}

/// Records an executed command in the index.
///
/// Updates both the global entry and the per-directory entry.
pub fn recordCommand(
    db: *Database,
    allocator: Allocator,
    cmd: []const u8,
    cwd: []const u8,
    exitCode: u8,
) !void {
    _ = exitCode;

    const nowMs = std.time.milliTimestamp();
    try upsertEntry(db, allocator, cmd, cwd, nowMs, false);
    try upsertEntry(db, allocator, cmd, cwd, nowMs, true);
}

/// Inserts a new entry into the record or updates an existing one if it already exists.
/// This function handles both creation and modification of record entries.
fn upsertEntry(
    db: *dbMod.Database,
    allocator: std.mem.Allocator,
    cmd: []const u8,
    cwd: []const u8,
    nowMs: i64,
    useDir: bool,
) !void {
    var keyBuf: [schema.MAX_KEY_LEN]u8 = undefined;
    const key = if (useDir)
        schema.dirKey(&keyBuf, cwd, cmd)
    else
        schema.globalKey(&keyBuf, cmd);

    // Read the current value to increment the counter
    const existing = try db.get(allocator, key);
    defer if (existing) |*v| @constCast(v).deinit(allocator);

    var entry = schema.Entry{ .count = 0, .lastMs = nowMs };

    if (existing) |v| {
        if (v == .string) {
            if (schema.decodeEntry(v.string)) |current| {
                entry.count = current.count;
            }
        }
    }

    entry.count += 1;
    entry.lastMs = nowMs;

    var valBuf: [64]u8 = undefined;
    const encoded = schema.encodeEntry(&valBuf, entry);
    const value = types.Value{ .string = encoded };
    try db.put(key, &value);

    const TTL_SECONDS: i64 = 90 * 24 * 60 * 60;
    const expireAt = std.time.timestamp() + TTL_SECONDS;
    _ = db.expire_at(key, expireAt) catch {};
}

test "recordCommand creates and increments entries" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const indexPath = try std.fmt.allocPrint(
        allocator,
        ".zig-cache/tmp/{s}/idx",
        .{tmp.sub_path},
    );
    defer allocator.free(indexPath);

    const db = try openIndex(allocator, indexPath);
    defer db.close() catch {};

    try recordCommand(db, allocator, "git status", "/home/enzo", 0);
    try recordCommand(db, allocator, "git status", "/home/enzo", 0);

    var keyBuf: [256]u8 = undefined;
    const key = schema.globalKey(&keyBuf, "git status");
    const val = (try db.get(allocator, key)).?;
    defer @constCast(&val).deinit(allocator);

    const entry = schema.decodeEntry(val.string).?;
    try testing.expectEqual(@as(u32, 2), entry.count);
}
