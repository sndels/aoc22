const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input = @embedFile("inputs/day03.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

const UT = u8;
const UniqueItems = std.AutoHashMap(UT, void);

fn intersect(sack0: UniqueItems, sack1: UniqueItems, allocator: Allocator) !UniqueItems {
    var intersection = UniqueItems.init(allocator);
    var sack0_iter = sack0.keyIterator();
    while (sack0_iter.next()) |item| {
        if (sack1.contains(item.*)) {
            try intersection.put(item.*, {});
        }
    }
    return intersection;
}

fn fold(comptime T: type, items: UniqueItems, func: fn (acc: T, item: UT) T, init: T) T {
    var acc = init;
    var iter = items.keyIterator();
    while (iter.next()) |item| {
        acc = func(acc, item.*);
    }
    return acc;
}

fn priority(item: u8) u64 {
    if (item >= 'a' and item <= 'z') {
        return item - 'a' + 1;
    } else {
        assert(item >= 'A' and item <= 'Z');
        return item - 'A' + 27;
    }
}

fn sumPriority(acc: u64, item: u8) u64 {
    return acc + priority(item);
}

fn getUniqueItems(items: []const u8, allocator: Allocator) !UniqueItems {
    var unique_set = UniqueItems.init(allocator);
    for (items) |item| {
        if (!unique_set.contains(item)) {
            try unique_set.put(item, {});
        }
    }
    return unique_set;
}

fn part1(rucksacks: *std.mem.SplitIterator(u8), allocator: Allocator) !u64 {
    var priority_sum: u64 = 0;
    while (rucksacks.next()) |sack| {
        const half_len = sack.len / 2;

        const compartment0 = sack[0..half_len];
        const compartment1 = sack[half_len..];
        assert(compartment0.len == compartment1.len);

        var compartment0_unique = try getUniqueItems(compartment0, allocator);
        defer compartment0_unique.deinit();
        var compartment1_unique = try getUniqueItems(compartment1, allocator);
        defer compartment1_unique.deinit();

        var shared_types = try intersect(compartment0_unique, compartment1_unique, allocator);
        defer shared_types.deinit();

        priority_sum += fold(u64, shared_types, sumPriority, 0);
    }
    return priority_sum;
}

fn part2(rucksacks: *std.mem.SplitIterator(u8), allocator: Allocator) !u64 {
    var priority_sum: u64 = 0;
    var trio: [3][]const u8 = .{ "", "", "" };
    var trio_i: u32 = 0;
    while (rucksacks.next()) |sack| {
        trio[trio_i] = sack;

        trio_i += 1;
        if (trio_i == 3) {
            var sack0_unique = try getUniqueItems(trio[0], allocator);
            defer sack0_unique.deinit();
            var sack1_unique = try getUniqueItems(trio[1], allocator);
            defer sack1_unique.deinit();
            var sack2_unique = try getUniqueItems(trio[2], allocator);
            defer sack2_unique.deinit();

            var shared_types01 = try intersect(sack0_unique, sack1_unique, allocator);
            defer shared_types01.deinit();

            var shared_types = try intersect(shared_types01, sack2_unique, allocator);
            defer shared_types.deinit();

            priority_sum += fold(u64, shared_types, sumPriority, 0);

            trio_i = 0;
        }
    }
    return priority_sum;
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
