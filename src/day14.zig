const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day14.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

fn getPart(allocator: Allocator) !u32 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try std.fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    return part;
}

const Vec2 = @Vector(2, u16);
const RockPath = std.ArrayList(Vec2);
const grain_start = Vec2{ 500, 0 };

const Grid = struct {
    const Self = @This();

    data: std.ArrayList(u8),
    top_left: Vec2,
    width: usize,
    height: usize,

    fn init(paths: std.ArrayList(RockPath), part: u32, allocator: Allocator) !Self {
        var top_left = Vec2{ std.math.maxInt(u16), std.math.maxInt(u16) };
        var bottom_right = Vec2{ 0, 0 };
        for (paths.items) |path| {
            for (path.items) |pos| {
                top_left = @min(top_left, pos);
                bottom_right = @max(bottom_right, pos);
            }
        }
        assert(@reduce(.And, top_left < bottom_right));
        top_left[1] = 0; // Full view in y
        if (part == 2) {
            // Floor is 2 below final rocks
            bottom_right[1] += 2;
            // Sand forms a pyramid with a step of 1
            top_left[0] = grain_start[0] - bottom_right[1];
            bottom_right[0] = grain_start[0] + bottom_right[1];
        }

        // Bounds are inclusive
        var width_height = bottom_right - top_left + Vec2{ 1, 1 };
        const width = width_height[0];
        const height = width_height[1];

        var data = std.ArrayList(u8).init(allocator);
        try data.appendNTimes('.', width * height);

        for (paths.items) |path| {
            assert(@reduce(.And, top_left <= path.items[0]));
            assert(@reduce(.And, bottom_right >= path.items[0]));

            var last_grid_pos = path.items[0] - top_left;

            for (path.items[1..]) |pos| {
                assert(@reduce(.And, top_left <= pos));
                assert(@reduce(.And, bottom_right >= pos));

                var grid_pos = pos - top_left;

                if (grid_pos[0] != last_grid_pos[0]) {
                    assert(grid_pos[1] == last_grid_pos[1]);

                    var start_i = @min(grid_pos[0], last_grid_pos[0]);
                    var end_i = @max(grid_pos[0], last_grid_pos[0]) + 1;

                    var i: u16 = start_i;
                    while (i < end_i) : (i += 1) {
                        data.items[grid_pos[1] * width + i] = '#';
                    }
                } else {
                    assert(grid_pos[1] != last_grid_pos[1]);

                    var start_i = @min(grid_pos[1], last_grid_pos[1]);
                    var end_i = @max(grid_pos[1], last_grid_pos[1]) + 1;

                    var i: u16 = start_i;
                    while (i < end_i) : (i += 1) {
                        data.items[i * width + grid_pos[0]] = '#';
                    }
                }

                last_grid_pos = grid_pos;
            }
        }

        if (part == 2) {
            var i: u16 = 0;
            while (i < width) : (i += 1) {
                data.items[(height - 1) * width + i] = '#';
            }
        }

        return Self{
            .data = data,
            .top_left = top_left,
            .width = width,
            .height = height,
        };
    }

    // Returns true if grain didn't fall off or wasn't blocked at the start
    fn dropSand(self: *Self) bool {
        var grain_pos = grain_start;

        // Tumble the grain until it stops or falls off
        while (self.isInside(grain_pos)) {
            var new_pos = grain_pos + Vec2{ 0, 1 };
            if (!self.isEmpty(new_pos)) {
                // Was one down, this is one down and to the left
                new_pos -= Vec2{ 1, 0 };
                if (!self.isEmpty(new_pos)) {
                    // Was one down and to the left, this is one down and to the right
                    new_pos += Vec2{ 2, 0 };
                    if (!self.isEmpty(new_pos)) {
                        break;
                    }
                }
            }
            grain_pos = new_pos;
        }
        if (self.isInside(grain_pos) and self.isEmpty(grain_pos)) {
            self.markSand(grain_pos - self.top_left);
            return true;
        }
        return false;
    }

    fn markSand(self: *Self, pos: Vec2) void {
        assert(pos[0] < self.width);
        assert(pos[1] < self.height);

        self.data.items[pos[1] * self.width + pos[0]] = 'o';
    }

    fn isInside(self: *const Self, global_pos: Vec2) bool {
        return (global_pos[0] >= self.top_left[0]) and (global_pos[0] < (self.top_left[0] + self.width));
    }

    fn isEmpty(self: *const Self, global_pos: Vec2) bool {
        if (global_pos[0] < self.top_left[0]) {
            return true;
        }
        const pos: Vec2 = global_pos - self.top_left;

        if (pos[0] >= self.width or pos[1] >= self.height) {
            return true;
        }

        return self.data.items[pos[1] * self.width + pos[0]] == '.';
    }

    fn deinit(self: *const Self) void {
        self.data.deinit();
    }

    fn print(self: *const Self) void {
        var row: usize = 0;
        while (row < self.height) : (row += 1) {
            const row_start = row * self.width;
            const row_end = row_start + self.width;
            dbgPrint("{s}\n", .{self.data.items[row_start..row_end]});
        }
    }
};

fn parseInput(allocator: Allocator) !std.ArrayList(RockPath) {
    var paths = std.ArrayList(RockPath).init(allocator);
    var lines = std.mem.split(u8, input_txt, line_ending);
    while (lines.next()) |line| {
        var path = RockPath.init(allocator);
        var coords = std.mem.split(u8, line, " -> ");
        while (coords.next()) |coord| {
            var parts = std.mem.split(u8, coord, ",");

            const x = try std.fmt.parseUnsigned(u16, parts.next().?, 10);
            const y = try std.fmt.parseUnsigned(u16, parts.next().?, 10);
            const pos = Vec2{ x, y };

            try path.append(pos);
        }
        try paths.append(path);
    }

    return paths;
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

    var timer = try std.time.Timer.start();

    const paths = try parseInput(allocator);
    defer {
        for (paths.items) |path| {
            path.deinit();
        }
        paths.deinit();
    }

    var grid = try Grid.init(paths, part, allocator);
    defer grid.deinit();

    var grain_count: u64 = 0;
    while (grid.dropSand()) {
        grain_count += 1;
    }
    grid.print();

    try stdout.print("{d} grains of sand come to rest", .{grain_count});

    // Make sure we end with a newline
    try stdout.print("\n", .{});

    try stdout.print("Took {d}ms\n ", .{timer.read() / std.time.ns_per_ms});

    try bw.flush(); // don't forget to flush!
}
