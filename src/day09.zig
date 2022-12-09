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

const Vec2 = struct {
    const Self = @This();

    x: i64,
    y: i64,

    fn add(self: *const Self, other: Vec2) Vec2 {
        return Vec2{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    fn sub(self: *const Self, other: Vec2) Vec2 {
        return Vec2{
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }
};

const Grid = struct {
    const Self = @This();

    data: std.ArrayList(u8),
    width: usize,
    height: usize,
    head: Vec2,
    tail: Vec2,
    allocator: Allocator,

    fn init(allocator: Allocator) !Self {
        const start = Vec2{
            .x = 0,
            .y = 4,
        };

        var ret = Self{
            .data = std.ArrayList(u8).init(allocator),
            .width = 5,
            .height = 5,
            .head = start,
            .tail = start,
            .allocator = allocator,
        };
        try ret.data.appendNTimes('.', ret.width * ret.height);
        ret.mark(start);

        return ret;
    }

    fn deinit(self: *const Self) void {
        self.data.deinit();
    }

    fn mark(self: *const Self, coord: Vec2) void {
        assert(coord.x >= 0);
        assert(coord.y >= 0);
        self.data.items[@intCast(usize, coord.y) * self.width + @intCast(usize, coord.x)] = '#';
    }

    fn maybeReallocate(self: *Self, next_coord: Vec2) !void {
        const x = next_coord.x;
        const y = next_coord.y;

        if (x < 0 or x >= self.width) {
            const extra_columns = 50;
            const new_width = self.width + extra_columns;

            var new_data = std.ArrayList(u8).init(self.allocator);
            try new_data.appendNTimes('.', new_width * self.height);

            var i: usize = 0;
            while (i < self.height) : (i += 1) {
                var new_offset = i * new_width;
                if (x < 0) {
                    new_offset += extra_columns;
                }
                const old_offset = i * self.width;
                std.mem.copy(u8, new_data.items[new_offset..], self.data.items[old_offset..(old_offset + self.width)]);
            }

            self.data.deinit();
            self.data = new_data;
            self.width = new_width;
            if (x < 0) {
                self.head.x += extra_columns;
                self.tail.x += extra_columns;
            }
        }

        if (y < 0 or y >= self.height) {
            const extra_rows = 50;
            const new_height = self.height + extra_rows;

            var new_data = std.ArrayList(u8).init(self.allocator);
            try new_data.appendNTimes('.', self.width * new_height);

            const start_i: usize = if (y < 0) extra_rows else 0;
            var i = start_i;
            while (i < start_i + self.height) : (i += 1) {
                const new_offset = i * self.width;
                const old_offset = (i - start_i) * self.width;
                std.mem.copy(u8, new_data.items[new_offset..], self.data.items[old_offset..(old_offset + self.width)]);
            }

            self.data.deinit();
            self.data = new_data;
            self.height = new_height;
            if (y < 0) {
                self.head.y += extra_rows;
                self.tail.y += extra_rows;
            }
        }
    }

    fn makeMove(self: *Self, dir: u8, dist: usize) !void {
        const step = switch (dir) {
            'U' => Vec2{
                .x = 0,
                .y = -1,
            },
            'D' => Vec2{
                .x = 0,
                .y = 1,
            },
            'L' => Vec2{
                .x = -1,
                .y = 0,
            },
            'R' => Vec2{
                .x = 1,
                .y = 0,
            },
            else => @panic("Invalid direction"),
        };

        var i: usize = 0;
        while (i < dist) : (i += 1) {
            self.head = self.head.add(step);

            try self.maybeReallocate(self.head);

            const head_dir = self.head.sub(self.tail);
            // TODO: integer abs?
            if (@fabs(@intToFloat(f32, head_dir.x)) > 1 or @fabs(@intToFloat(f32, head_dir.y)) > 1) {
                // Move at most 1 step in either direction, handling all movement cases
                const tail_move = Vec2{
                    .x = @max(@min(head_dir.x, 1), -1),
                    .y = @max(@min(head_dir.y, 1), -1),
                };
                self.tail = self.tail.add(tail_move);
                self.mark(self.tail);
            }

            // self.print();
        }
    }

    fn print(self: *const Self) void {
        var j: usize = 0;
        while (j < self.height) : (j += 1) {
            var i: usize = 0;
            while (i < self.width) : (i += 1) {
                if (self.head.x == i and self.head.y == j) {
                    dbgPrint("H", .{});
                } else if (self.tail.x == i and self.tail.y == j) {
                    dbgPrint("T", .{});
                } else {
                    dbgPrint("{c}", .{self.data.items[j * self.width + i]});
                }
            }
            dbgPrint("\n", .{});
        }
        dbgPrint("\n", .{});
    }

    fn countTailVisits(self: *const Self) usize {
        return std.mem.count(u8, self.data.items, "#");
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
