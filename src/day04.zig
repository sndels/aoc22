const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input = @embedFile("inputs/day04.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

const Assignment = struct {
    first: u8,
    last: u8,
};

const Pair = struct {
    first: Assignment,
    second: Assignment,
};

fn parseAssignment(line: []const u8) !Assignment {
    var ends = std.mem.split(u8, line, "-");

    const first = try std.fmt.parseUnsigned(u8, ends.next().?, 10);
    const last = try std.fmt.parseUnsigned(u8, ends.next().?, 10);

    return Assignment{
        .first = first,
        .last = last,
    };
}

fn parsePair(line: []const u8) !Pair {
    var pairs = std.mem.split(u8, line, ",");

    const first = try parseAssignment(pairs.next().?);
    const second = try parseAssignment(pairs.next().?);

    return Pair{
        .first = first,
        .second = second,
    };
}

fn parseInput(allocator: Allocator) !std.ArrayList(Pair) {
    var ret = std.ArrayList(Pair).init(allocator);

    var lines = std.mem.split(u8, input, line_ending);
    while (lines.next()) |line| {
        const pair = try parsePair(line);
        try ret.append(pair);
    }

    return ret;
}

fn fullyContains(assignment: Assignment, other: Assignment) bool {
    return assignment.first <= other.first and assignment.last >= other.last;
}

fn overlaps(assignment: Assignment, other: Assignment) bool {
    return (assignment.first <= other.first and assignment.last >= other.first) or
        (other.first <= assignment.first and other.last >= assignment.first);
}

pub fn main() !void {
    // Let's not use the arena allocator to get comfortable with defer dtors
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try std.fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const pairs = try parseInput(allocator);
    defer pairs.deinit();

    if (part == 1) {
        var fully_contained_count: u64 = 0;
        for (pairs.items) |pair| {
            if (fullyContains(pair.first, pair.second) or fullyContains(pair.second, pair.first)) {
                fully_contained_count += 1;
            }
        }
        try stdout.print("{d} assignments fully contained", .{fully_contained_count});
    } else {
        var overlap_count: u64 = 0;
        for (pairs.items) |pair| {
            if (overlaps(pair.first, pair.second)) {
                overlap_count += 1;
            }
        }
        try stdout.print("{d} pairs overlap", .{overlap_count});
    }

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
