const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day10.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

fn getPart(allocator: Allocator) !u32 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try std.fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    return part;
}

fn runOps(comptime Context: type, during_op_fn: fn (context: *Context, cycle: u64, X: i64) void, context: *Context) !void {
    var cycle: u64 = 1;
    var X: i64 = 1;
    var lines = std.mem.split(u8, input_txt, line_ending);
    while (lines.next()) |line| {
        var parts = std.mem.split(u8, line, " ");

        const op = parts.next().?;
        const arg = try std.fmt.parseInt(i64, parts.next() orelse "0", 10);

        if (std.mem.eql(u8, op, "noop")) {
            during_op_fn(context, cycle, X);
            cycle += 1;
        } else if (std.mem.eql(u8, op, "addx")) {
            during_op_fn(context, cycle, X);
            cycle += 1;
            during_op_fn(context, cycle, X);
            cycle += 1;
            X += arg;
        } else {
            @panic("Unknown instruction");
        }
    }
}

fn sumInterestingSignalStrengths(signal_strength_sum: *i64, cycle: u64, X: i64) void {
    if (cycle >= 20 and ((cycle - 20) % 40) == 0) {
        const signal_strength = @intCast(i64, cycle) * X;
        signal_strength_sum.* += signal_strength;
    }
}

fn drawPx(crt: *[6][40]u8, cycle: u64, X: i64) void {
    const row = (cycle - 1) / 40;
    const px = (cycle - 1) % 40;
    if (px >= X - 1 and px <= X + 1) {
        crt[row][px] = '#';
    } else {
        crt[row][px] = '.';
    }
}

pub fn main() !void {
    // Let's not use the arena allocator to get comfortable with defer dtors
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const part = try getPart(allocator);

    if (part == 1) {
        var signal_strength_sum: i64 = 0;
        try runOps(i64, sumInterestingSignalStrengths, &signal_strength_sum);

        try stdout.print("Sum of interesting signal strenghts is {d}", .{signal_strength_sum});
    } else {
        var crt: [6][40]u8 = [_][40]u8{[_]u8{'X'} ** 40} ** 6;
        try runOps([6][40]u8, drawPx, &crt);

        for (crt) |row| {
            try stdout.print("{s}\n", .{row});
        }
    }

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
