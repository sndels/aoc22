const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day11.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

fn getPart(allocator: Allocator) !u32 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try std.fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    return part;
}

fn last(comptime T: type, array: *std.ArrayList(T)) *T {
    return &array.items[array.items.len - 1];
}

const OperationType = enum {
    Multiply,
    Sum,
};

const RhsOld: u64 = 0xFFFF_FFFF_FFFF_FFFF;

const Operation = struct {
    op_type: OperationType,
    rhs: u64,
};

const Monkey = struct {
    const Self = @This();

    item_worry_levels: std.ArrayList(u64),
    operation: Operation,
    test_denominator: u64,
    passing_target: usize,
    failing_target: usize,
    inspection_count: u64,

    fn init(allocator: Allocator) Self {
        return Self{
            .item_worry_levels = std.ArrayList(u64).init(allocator),
            .operation = Operation{
                .op_type = OperationType.Sum,
                .rhs = 0,
            },
            .test_denominator = 1,
            .passing_target = 0,
            .failing_target = 0,
            .inspection_count = 0,
        };
    }

    fn deinit(self: *const Self) void {
        self.item_worry_levels.deinit();
    }
};

fn parseInput(allocator: Allocator) !std.ArrayList(Monkey) {
    var monkeys = std.ArrayList(Monkey).init(allocator);

    var lines = std.mem.split(u8, input_txt, line_ending);
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        if (std.mem.startsWith(u8, line, "Monkey")) {
            try monkeys.append(Monkey.init(allocator));
        } else if (std.mem.startsWith(u8, line, "  Starting items:")) {
            var monkey = last(Monkey, &monkeys);
            var parts = std.mem.split(u8, line, ": ");

            _ = parts.next().?; // "  Starting items: "

            var items = std.mem.split(u8, parts.next().?, ", ");
            while (items.next()) |item| {
                const worry_level = try std.fmt.parseUnsigned(u64, item, 10);
                try monkey.item_worry_levels.append(worry_level);
            }
        } else if (std.mem.startsWith(u8, line, "  Operation: new = old ")) {
            var monkey = last(Monkey, &monkeys);
            var parts = std.mem.split(u8, line, "old ");

            _ = parts.next().?; // "  Operation: new = "

            var op_and_rhs = parts.next().?;
            assert(op_and_rhs[0] == '*' or op_and_rhs[0] == '+');

            var op_type = if (op_and_rhs[0] == '*') OperationType.Multiply else OperationType.Sum;

            var rhs_str = op_and_rhs[2..];
            var rhs = RhsOld;
            if (!std.mem.eql(u8, rhs_str, "old")) {
                rhs = try std.fmt.parseUnsigned(u64, rhs_str, 10);
            }

            monkey.operation = Operation{
                .op_type = op_type,
                .rhs = rhs,
            };
        } else if (std.mem.startsWith(u8, line, "  Test: divisible by ")) {
            var monkey = last(Monkey, &monkeys);
            var parts = std.mem.split(u8, line, "by ");

            _ = parts.next().?; // "  Test: divisible "

            monkey.test_denominator = try std.fmt.parseUnsigned(u64, parts.next().?, 10);
        } else if (std.mem.startsWith(u8, line, "    If true: throw to monkey ")) {
            var monkey = last(Monkey, &monkeys);
            var parts = std.mem.split(u8, line, "monkey ");

            _ = parts.next().?; // "    If true: throw to "

            monkey.passing_target = try std.fmt.parseUnsigned(usize, parts.next().?, 10);
        } else if (std.mem.startsWith(u8, line, "    If false:")) {
            var monkey = last(Monkey, &monkeys);
            var parts = std.mem.split(u8, line, "monkey ");

            _ = parts.next().?; // "    If true: throw to "

            monkey.failing_target = try std.fmt.parseUnsigned(usize, parts.next().?, 10);
        } else {
            @panic("Unexpected input line content");
        }
    }

    return monkeys;
}

fn findRing(monkeys: []Monkey) u64 {
    // Don't care about the smallest ring that contains the divisors, just get a ring
    var ring: u64 = 1;
    for (monkeys) |monkey| {
        ring *= monkey.test_denominator;
    }
    return ring;
}

fn doRound(monkeys: []Monkey, get_relieved: bool, ring: u64) !void {
    for (monkeys) |*monkey| {
        for (monkey.item_worry_levels.items) |*worry_level| {
            // Inspect
            monkey.inspection_count += 1;

            // Increase worry
            const rhs = if (monkey.operation.rhs == RhsOld) worry_level.* else monkey.operation.rhs;
            if (monkey.operation.op_type == OperationType.Multiply) {
                worry_level.* *= rhs;
            } else if (monkey.operation.op_type == OperationType.Sum) {
                worry_level.* += rhs;
            } else {
                @panic("Unknown OperationType");
            }

            // Evaluate relief
            if (get_relieved) {
                worry_level.* /= 3;
            } else {
                // Avoid overflow by keeping the value in a ring that contains all monkeys' test denominators
                worry_level.* %= ring;
            }

            // Throw
            const target = if (worry_level.* % monkey.test_denominator == 0) monkey.passing_target else monkey.failing_target;
            try monkeys[target].item_worry_levels.append(worry_level.*);
        }
        // Monkey threw all its items
        monkey.item_worry_levels.clearRetainingCapacity();
    }
}

fn inspectionCountGreaterThan(_: void, m0: Monkey, m1: Monkey) bool {
    return m0.inspection_count > m1.inspection_count;
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

    var monkeys = try parseInput(allocator);
    defer {
        for (monkeys.items) |monkey| {
            monkey.deinit();
        }
        monkeys.deinit();
    }

    var ring = findRing(monkeys.items);

    if (part == 1) {
        var round: usize = 0;
        while (round < 20) : (round += 1) {
            try doRound(monkeys.items, true, ring);
        }
    } else {
        var round: usize = 0;
        while (round < 10_000) : (round += 1) {
            try doRound(monkeys.items, false, ring);
        }
    }

    std.sort.sort(Monkey, monkeys.items, {}, inspectionCountGreaterThan);

    const monkey_business = monkeys.items[0].inspection_count * monkeys.items[1].inspection_count;
    try stdout.print("Level of monkey business is {d}", .{monkey_business});

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
