const std = @import("std");
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input = @embedFile("inputs/day03.txt");

const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

pub fn intersect(comptime T: type, sack0: []const T, sack1: []const T, allocator: std.mem.Allocator) !std.ArrayList(T) {
    var intersection = std.ArrayList(T).init(allocator);
    for (sack0) |item| {
        if (std.mem.indexOfScalar(T, sack1, item)) |_| {
            if (std.mem.indexOfScalar(T, intersection.items, item)) |_| {} else {
                try intersection.append(item);
            }
        }
    }
    return intersection;
}

pub fn priority(item: u8) u64 {
    if (item >= 'a' and item <= 'z') {
        return item - 'a' + 1;
    } else {
        assert(item >= 'A' and item <= 'Z');
        return item - 'A' + 27;
    }
}

pub fn part1(rucksacks: *std.mem.SplitIterator(u8), allocator: std.mem.Allocator) !u64 {
    var priority_sum: u64 = 0;
    while (rucksacks.next()) |sack| {
        const half_len = sack.len / 2;
        const sack0 = sack[0..half_len];
        const sack1 = sack[half_len..];
        assert(sack0.len == sack1.len);
        const shared_items = try intersect(u8, sack0, sack1, allocator);
        defer shared_items.deinit();
        for (shared_items.items) |item| {
            priority_sum += priority(item);
        }
    }
    return priority_sum;
}

pub fn part2(rucksacks: *std.mem.SplitIterator(u8), allocator: std.mem.Allocator) !u64 {
    var priority_sum: u64 = 0;
    var trio: [3][]const u8 = .{ "", "", "" };
    var trio_i: u32 = 0;
    while (rucksacks.next()) |sack| {
        trio[trio_i] = sack;
        trio_i += 1;
        if (trio_i == 3) {
            const shared_items01 = try intersect(u8, trio[0], trio[1], allocator);
            defer shared_items01.deinit();
            const shared_items = try intersect(u8, shared_items01.items, trio[2], allocator);
            defer shared_items.deinit();
            for (shared_items.items) |item| {
                priority_sum += priority(item);
            }
            trio_i = 0;
        }
    }
    return priority_sum;
}

pub fn main() !void {
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

    var rucksacks = std.mem.split(u8, input, line_ending);
    const priority_sum = blk: {
        if (part == 1) {
            break :blk try part1(&rucksacks, allocator);
        } else {
            break :blk try part2(&rucksacks, allocator);
        }
    };

    // Print result here
    try stdout.print("Priority sum: {d}", .{priority_sum});

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
