const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day05.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";
const Step = struct {
    crate_count: u8,
    src: u8,
    dst: u8,
};

const Stack = std.ArrayList(u8);

const Input = struct {
    stacks: std.ArrayList(Stack),
    steps: std.ArrayList(Step),

    pub fn deinit(self: *const Input) void {
        self.steps.deinit();
        for (self.stacks.items) |stack| {
            stack.deinit();
        }
        self.stacks.deinit();
    }
};

fn parseStacks(lines: *LinesIter, allocator: Allocator) !std.ArrayList(Stack) {
    var stack_lines = std.ArrayList([]const u8).init(allocator);
    defer stack_lines.deinit();

    // Don't assume trailing whitespace in the input so let's use the index line
    // to infer stack count before parsing crates
    while (lines.next()) |line| {
        if (line.len == 0) {
            break;
        }
        try stack_lines.append(line);
    }

    var stacks = std.ArrayList(Stack).init(allocator);
    {
        // Last line will have all the stack indices, each taking up 3 + 1 characters
        // except for the final one that will be less than that
        const stack_count = (stack_lines.items[stack_lines.items.len - 1].len / 4) + 1;
        var i: u32 = 0;
        while (i < stack_count) : (i += 1) {
            try stacks.append(Stack.init(allocator));
        }
    }

    {
        // Ignore the last line that has the stack indices
        _ = stack_lines.pop();
        for (stack_lines.items) |line| {
            // Crate IDs are 4 spaces apart
            var line_i: u32 = 1;
            while (line_i < line.len) : (line_i += 4) {
                const crate = line[line_i];
                if (crate != ' ') {
                    try stacks.items[line_i / 4].append(crate);
                }
            }
        }
        // We filled the stacks in reverse order
        for (stacks.items) |stack| {
            std.mem.reverse(u8, stack.items);
        }
    }

    return stacks;
}

fn parseSteps(lines: *LinesIter, allocator: Allocator) !std.ArrayList(Step) {
    var steps = std.ArrayList(Step).init(allocator);

    while (lines.next()) |line| {
        var tokens = std.mem.split(u8, line, " ");

        _ = tokens.next().?; // move
        const count = tokens.next().?;

        _ = tokens.next().?; // from
        const src = tokens.next().?;

        _ = tokens.next().?; // to
        const dst = tokens.next().?;

        try steps.append(Step{
            .crate_count = try std.fmt.parseUnsigned(u8, count, 10),
            .src = try std.fmt.parseUnsigned(u8, src, 10),
            .dst = try std.fmt.parseUnsigned(u8, dst, 10),
        });
    }

    return steps;
}

fn parseInput(allocator: Allocator) !Input {
    var lines = std.mem.split(u8, input_txt, line_ending);
    return Input{
        .stacks = try parseStacks(&lines, allocator),
        .steps = try parseSteps(&lines, allocator),
    };
}

fn part1Move(crate_count: u8, src: *Stack, dst: *Stack) !void {
    var i: u32 = 0;
    while (i < crate_count) : (i += 1) {
        try dst.append(src.pop());
    }
}

fn part2Move(crate_count: u8, src: *Stack, dst: *Stack) !void {
    var i: usize = src.items.len - crate_count;
    while (i < src.items.len) : (i += 1) {
        try dst.append(src.items[i]);
    }
    try src.resize(src.items.len - crate_count);
}

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

    const input = try parseInput(allocator);
    defer input.deinit();

    var stacks = input.stacks.items;
    var steps = input.steps.items;
    for (steps) |step| {
        var src = &stacks[step.src - 1];
        var dst = &stacks[step.dst - 1];
        if (part == 1) {
            try part1Move(step.crate_count, src, dst);
        } else {
            try part2Move(step.crate_count, src, dst);
        }
    }

    try stdout.print("Top crates are ", .{});
    for (stacks) |stack| {
        try stdout.print("{c}", .{stack.items[stack.items.len - 1]});
    }

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
