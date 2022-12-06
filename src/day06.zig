const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day06.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

fn getPart(allocator: Allocator) !u32 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try std.fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    return part;
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
    // Requires type to force runtime value
    const marker_len: usize = if (part == 1) 4 else 14;

    var char_set = std.AutoHashMap(u8, void).init(allocator);
    defer char_set.deinit();

    var marker_start: usize = 0;
    while_input: while (marker_start < input_txt.len - marker_len) : (marker_start += 1) {
        // Compare all character pairs in the supposed marker
        var i: usize = 0;
        char_set.clearRetainingCapacity();
        while (i < marker_len) : (i += 1) {
            try char_set.put(input_txt[marker_start + i], {});
        }
        if (char_set.count() == marker_len) {
            break :while_input;
        }
    }

    try stdout.print("Need to process {d} characters", .{marker_start + marker_len});

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
