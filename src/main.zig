const std = @import("std");
const builtin = @import("builtin");
const zeno = @import("zeno");
const recordMod = @import("record.zig");
const queryMod = @import("query.zig");
const shellZsh = @import("shell/zsh.zig");
const shellBash = @import("shell/bash.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        std.process.exit(1);
    }

    const subcmd = args[1];

    if (std.mem.eql(u8, subcmd, "init")) {
        if (args.len < 3) {
            std.debug.print("Usage: zeno-shell init <zsh|bash>\n", .{});
            std.process.exit(1);
        }
        var buf: [4096]u8 = undefined;
        var stdout = std.fs.File.stdout().writer(&buf);
        const shell = args[2];
        if (std.mem.eql(u8, shell, "zsh")) {
            try shellZsh.printInitScript(&stdout.interface);
        } else if (std.mem.eql(u8, shell, "bash")) {
            try shellBash.printInitScript(&stdout.interface);
        } else {
            std.debug.print("Unknown shell: {s}\n", .{shell});
            std.process.exit(1);
        }
        try stdout.interface.flush();
        return;
    }

    if (std.mem.eql(u8, subcmd, "record")) {
        if (args.len < 5) {
            std.debug.print("Usage: zeno-shell record <cmd> <cwd> <exit_code>\n", .{});
            std.process.exit(1);
        }
        const cmd = args[2];
        const cwd = args[3];
        const exitCode = std.fmt.parseInt(u8, args[4], 10) catch 0;

        const indexPath = try resolveIndexPath(allocator);
        defer allocator.free(indexPath);

        const db = try recordMod.openIndex(allocator, indexPath);
        defer db.close() catch {};

        try recordMod.recordCommand(db, allocator, cmd, cwd, exitCode);
        return;
    }

    if (std.mem.eql(u8, subcmd, "query")) {
        if (args.len < 4) {
            std.debug.print("Usage: zeno-shell query <prefix> <cwd>\n", .{});
            std.process.exit(1);
        }
        const prefix = args[2];
        const cwd = args[3];

        const indexPath = try resolveIndexPath(allocator);
        defer allocator.free(indexPath);

        const db = try recordMod.openIndex(allocator, indexPath);
        defer db.close() catch {};

        const suggestions = try queryMod.suggest(db, allocator, prefix, cwd, 5);
        defer {
            for (suggestions) |s| allocator.free(s.cmd);
            allocator.free(suggestions);
        }

        var buf: [4096]u8 = undefined;
        var stdout = std.fs.File.stdout().writer(&buf);
        for (suggestions) |s| {
            try stdout.interface.print("{s}\n", .{s.cmd});
        }
        try stdout.interface.flush();
        return;
    }

    printUsage();
    std.process.exit(1);
}

fn resolveIndexPath(allocator: std.mem.Allocator) ![]const u8 {
    const home = std.posix.getenv("HOME") orelse "/tmp";

    const base = switch (builtin.os.tag) {
        .macos => try std.fmt.allocPrint(
            allocator,
            "{s}/Library/Application Support/zeno-shell",
            .{home},
        ),
        else => try std.fmt.allocPrint(
            allocator,
            "{s}/.local/share/zeno-shell",
            .{home},
        ),
    };
    defer allocator.free(base);

    // Create the directory if it doesn't exist yet
    std.fs.makeDirAbsolute(base) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    return std.fmt.allocPrint(allocator, "{s}/index", .{base});
}

fn printUsage() void {
    std.debug.print(
        \\Usage: zeno-shell <command>
        \\
        \\Commands:
        \\  init <zsh|bash>             Print shell integration script
        \\  record <cmd> <cwd> <code>   Record an executed command
        \\  query <prefix> <cwd>        Query suggestions for a prefix
        \\
    , .{});
}
