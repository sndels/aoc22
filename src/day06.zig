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

    var prev_chars= std.fifo.LinearFifo(u8, .Dynamic).init(allocator);
    defer prev_chars.deinit();

    var input_i: usize = 0;
    while_input: while (input_i < input_txt.len) : (input_i += 1) {
        try prev_chars.writeItem(input_txt[input_i]);
        if (prev_chars.readableLength() > marker_len) {
            _ = prev_chars.readItem();
        }
        if (prev_chars.readableLength() == marker_len) {
            // Compare all character pairs
            var i: usize = 0;
            var all_unique = true;
            while_i: while (i < marker_len) : (i += 1) {
                var j: usize = i + 1;
                while (j < marker_len) : (j += 1) {
                    if (prev_chars.peekItem(i) == prev_chars.peekItem(j)) {
                        all_unique = false;
                        break :while_i;
                    }
                }
            }
            if (all_unique) {
                break :while_input;
            }
        }
    }

    try stdout.print("Need to process {d} characters", .{input_i + 1});

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
