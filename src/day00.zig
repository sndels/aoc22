const std = @import("std");
const dbgPrint = std.debug.print;
const assert = std.debug.assert;
const fmt = std.fmt;

const input = @embedFile("inputs/day00.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    // Day code here

    // dbgPrint("This is a dbg_print that self flushes\n", .{});

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Print result here
    try stdout.print("{s}", .{input});
    if (part == 2) {
        try stdout.print("part 2", .{});
    }
    try bw.flush(); // don't forget to flush!
}
