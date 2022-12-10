const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day09.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

fn getPart(allocator: Allocator) !u32 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try std.fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    return part;
}

const Vec2 = @Vector(2, i32);

const TailVisits = std.AutoHashMap(Vec2, void);

const Grid = struct {
    const Self = @This();

    width: usize,
    height: usize,
    head: Vec2,
    tail: Vec2,
    tail_visits: TailVisits,
    allocator: Allocator,

    fn init(allocator: Allocator) !Self {
        const start = Vec2{ 0, 0 };

        var ret = Self{
            .width = 5,
            .height = 5,
            .head = start,
            .tail = start,
            .tail_visits = std.AutoHashMap(Vec2, void).init(allocator),
            .allocator = allocator,
        };
        try ret.mark(start);

        return ret;
    }

    fn deinit(self: *Self) void {
        self.tail_visits.deinit();
    }

    fn mark(self: *Self, coord: Vec2) !void {
        try self.tail_visits.put(coord, {});
    }

    fn makeMove(self: *Self, dir: u8, dist: usize) !void {
        const step = switch (dir) {
            'U' => Vec2{ 0, 1 },
            'D' => Vec2{ 0, -1 },
            'L' => Vec2{ -1, 0 },
            'R' => Vec2{ 1, 0 },
            else => @panic("Invalid direction"),
        };

        var i: usize = 0;
        while (i < dist) : (i += 1) {
            self.head = self.head + step;

            const head_dir = self.head - self.tail;
            const abs_head_dir = @max(head_dir, head_dir * Vec2{ -1, -1 });
            if (@reduce(.Or, abs_head_dir > Vec2{ 1, 1 })) {
                // Move at most 1 step in either direction
                const tail_move = @max(@min(head_dir, Vec2{ 1, 1 }), Vec2{ -1, -1 });
                self.tail = self.tail + tail_move;
                try self.mark(self.tail);
            }

            // self.print();
        }
    }

    fn print(self: *const Self) void {
        var min_p = self.head;
        var max_p = self.head;
        min_p = @min(min_p, self.tail);
        max_p = @max(max_p, self.tail);

        var keys = self.tail_visits.keyIterator();
        while (keys.next()) |key| {
            min_p = @min(min_p, key.*);
            max_p = @max(max_p, key.*);
        }

        const width = max_p[0] - min_p[0] + 1;
        const height = max_p[1] - min_p[1] + 1;

        // Coordinate system is X left, Y up
        const top_left = Vec2{ min_p[0], max_p[1] };

        var j: i32 = 0;
        while (j < height) : (j += 1) {
            var i: i32 = 0;
            while (i < width) : (i += 1) {
                // Down is -Y
                const pos = top_left + Vec2{ i, -j };
                if (@reduce(.And, pos == self.head)) {
                    dbgPrint("H", .{});
                } else if (@reduce(.And, pos == self.tail)) {
                    dbgPrint("T", .{});
                } else if (self.tail_visits.contains(pos)) {
                    dbgPrint("#", .{});
                } else {
                    dbgPrint(".", .{});
                }
            }
            dbgPrint("\n", .{});
        }
    }

    fn countTailVisits(self: *const Self) usize {
        return self.tail_visits.count();
    }
};

pub fn main() !void {
    // Let's not use the arena allocator to get comfortable with defer dtors
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const part = try getPart(allocator);

    var grid = try Grid.init(allocator);
    defer grid.deinit();

    var lines = std.mem.split(u8, input_txt, line_ending);
    while (lines.next()) |line| {
        var parts = std.mem.split(u8, line, " ");

        const dir = parts.next().?[0];
        const dist = try std.fmt.parseUnsigned(usize, parts.next().?, 10);

        try grid.makeMove(dir, dist);
    }

    grid.print();

    if (part == 1) {
        try stdout.print("Tail visited {d} positions", .{grid.countTailVisits()});
    } else {}

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
