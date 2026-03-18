const std = @import("std");

pub const GLOBAL_PREFIX = "g:";
pub const DIR_PREFIX = "d:";
pub const MAX_KEY_LEN = 2048;

pub const Entry = struct {
    count: u32,
    lastMs: i64,
};

/// Builds the global key for a command. Format: "g:{cmd}"
pub fn globalKey(buf: []u8, cmd: []const u8) []const u8 {
    return std.fmt.bufPrint(buf, GLOBAL_PREFIX ++ "{s}", .{cmd}) catch unreachable;
}

/// Builds the per-directory key. Format: "d:{cwd}:{cmd}"
pub fn dirKey(buf: []u8, cwd: []const u8, cmd: []const u8) []const u8 {
    return std.fmt.bufPrint(buf, DIR_PREFIX ++ "{s}:{s}", .{ cwd, cmd }) catch unreachable;
}

/// Builds the global search prefix. Format: "g:{query}"
pub fn globalQueryPrefix(buf: []u8, query: []const u8) []const u8 {
    return std.fmt.bufPrint(buf, GLOBAL_PREFIX ++ "{s}", .{query}) catch unreachable;
}

/// Builds the per-directory search prefix. Format: "d:{cwd}:{query}"
pub fn dirQueryPrefix(buf: []u8, cwd: []const u8, query: []const u8) []const u8 {
    return std.fmt.bufPrint(buf, DIR_PREFIX ++ "{s}:{s}", .{ cwd, query }) catch unreachable;
}

/// Serializes an Entry to string. Format: "{count}:{lastMs}"
pub fn encodeEntry(buf: []u8, entry: Entry) []const u8 {
    return std.fmt.bufPrint(buf, "{d}:{d}", .{ entry.count, entry.lastMs }) catch unreachable;
}

/// Deserializes a string into an Entry. Returns null if the format is invalid.
pub fn decodeEntry(raw: []const u8) ?Entry {
    const sep = std.mem.indexOf(u8, raw, ":") orelse return null;
    const count = std.fmt.parseInt(u32, raw[0..sep], 10) catch return null;
    const lastMs = std.fmt.parseInt(i64, raw[sep + 1 ..], 10) catch return null;
    return .{ .count = count, .lastMs = lastMs };
}

/// Extracts the command from a global key by stripping the "g:" prefix.
pub fn extractCmdFromGlobalKey(key: []const u8) []const u8 {
    if (key.len < GLOBAL_PREFIX.len) return key;
    return key[GLOBAL_PREFIX.len..];
}

/// Extracts the command from a per-directory key by stripping "d:{cwd}:".
pub fn extractCmdFromDirKey(key: []const u8, cwd: []const u8) []const u8 {
    const prefixLen = DIR_PREFIX.len + cwd.len + 1; // "d:" + cwd + ":"
    if (key.len <= prefixLen) return key;
    return key[prefixLen..];
}

test "encode and decode roundtrip" {
    const entry = Entry{ .count = 42, .lastMs = 1234567890 };
    var buf: [64]u8 = undefined;
    const encoded = encodeEntry(&buf, entry);
    const decoded = decodeEntry(encoded).?;
    try std.testing.expectEqual(entry.count, decoded.count);
    try std.testing.expectEqual(entry.lastMs, decoded.lastMs);
}

test "globalKey has correct format" {
    var buf: [256]u8 = undefined;
    const key = globalKey(&buf, "git commit -m");
    try std.testing.expectEqualStrings("g:git commit -m", key);
}

test "extractCmdFromDirKey strips prefix correctly" {
    var buf: [512]u8 = undefined;
    const cwd = "/home/enzo/projects";
    const cmd = "zig build test";
    const key = dirKey(&buf, cwd, cmd);
    const extracted = extractCmdFromDirKey(key, cwd);
    try std.testing.expectEqualStrings(cmd, extracted);
}
