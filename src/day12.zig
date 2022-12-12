const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day12.txt");
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

const Vec2 = @Vector(2, usize);
const null_pos = Vec2{ std.math.maxInt(usize), std.math.maxInt(usize) };
const not_seen_distance = std.math.maxInt(u64);
const PosQueue = std.fifo.LinearFifo(Vec2, .Dynamic);
const DistanceMap = std.AutoHashMap(Vec2, u64);

const HeightMap = struct {
    const Self = @This();

    rows: std.ArrayList([]const u8),
    width: usize,
    height: usize,

    fn init(allocator: Allocator) Self {
        return Self{
            .rows = std.ArrayList([]const u8).init(allocator),
            .width = 0,
            .height = 0,
        };
    }

    fn deinit(self: *const Self) void {
        self.rows.deinit();
    }

    fn getHeight(self: *const Self, pos: Vec2) u8 {
        assert(pos[0] < self.width);
        assert(pos[1] < self.height);

        return self.rows.items[pos[1]][pos[0]];
    }
};

fn parseInput(allocator: Allocator) !HeightMap {
    var height_map = HeightMap.init(allocator);

    var rows = &height_map.rows;

    var lines = std.mem.split(u8, input_txt, line_ending);
    while (lines.next()) |line| {
        try rows.append(line);
    }
    assert(rows.items.len > 0);
    assert(rows.items[0].len > 0);

    height_map.width = rows.items[0].len;
    height_map.height = rows.items.len;

    return height_map;
}

fn updateDistance(pos: Vec2, new_distance: u64, distances: *DistanceMap) !void {
    assert(distances.contains(pos));

    if (distances.get(pos).? > new_distance) {
        try distances.put(pos, new_distance);
    }
}

fn height(map_value: u8) u8 {
    if (map_value == 'S') {
        return 'a';
    } else if (map_value == 'E') {
        return 'z';
    }
    return map_value;
}

fn heightDiff(from: u8, to: u8) i8 {
    const from_height = height(from);
    const to_height = height(to);

    return @intCast(i8, to_height - 'a') - @intCast(i8, from_height - 'a');
}

fn updateNeighbor(neighbor_pos: Vec2, new_distance: u64, self_height: u8, height_map: HeightMap, queue: *PosQueue, distances: *DistanceMap) !void {
    const neighbor_height = height_map.getHeight(neighbor_pos);

    if (heightDiff(self_height, neighbor_height) <= 1) {
        if (distances.get(neighbor_pos).? == not_seen_distance) {
            try queue.writeItem(neighbor_pos);
        }

        try updateDistance(neighbor_pos, new_distance, distances);
    }
}

fn findShortestPathSteps(height_map: HeightMap, start: Vec2, end: Vec2, allocator: Allocator) !u64 {
    var queue = PosQueue.init(allocator);
    defer queue.deinit();

    var distances = DistanceMap.init(allocator);
    defer distances.deinit();

    {
        var j: usize = 0;
        while (j < height_map.height) : (j += 1) {
            var i: usize = 0;
            while (i < height_map.width) : (i += 1) {
                try distances.put(Vec2{ i, j }, not_seen_distance);
            }
        }
    }
    try distances.put(start, 0);

    try queue.writeItem(start);

    var steps: u64 = std.math.maxInt(u64);
    while (queue.readItem()) |pos| {
        assert(distances.get(pos).? < not_seen_distance);

        if (@reduce(.And, pos == end)) {
            steps = distances.get(pos).?;
            break;
        }

        const new_distance = distances.get(pos).? + 1;
        const self_height = height_map.getHeight(pos);

        if (pos[0] > 0) {
            const neighbor_pos = Vec2{ pos[0] - 1, pos[1] };
            try updateNeighbor(neighbor_pos, new_distance, self_height, height_map, &queue, &distances);
        }
        if (pos[1] > 0) {
            const neighbor_pos = Vec2{ pos[0], pos[1] - 1 };
            try updateNeighbor(neighbor_pos, new_distance, self_height, height_map, &queue, &distances);
        }
        if (pos[0] < height_map.width - 1) {
            const neighbor_pos = Vec2{ pos[0] + 1, pos[1] };
            try updateNeighbor(neighbor_pos, new_distance, self_height, height_map, &queue, &distances);
        }
        if (pos[1] < height_map.height - 1) {
            const neighbor_pos = Vec2{ pos[0], pos[1] + 1 };
            try updateNeighbor(neighbor_pos, new_distance, self_height, height_map, &queue, &distances);
        }
    }

    return steps;
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

    const height_map = try parseInput(allocator);
    defer height_map.deinit();

    if (part == 1) {
        var start = null_pos;
        var end = null_pos;
        for (height_map.rows.items) |row, row_i| {
            if (std.mem.indexOf(u8, row, "S")) |i| {
                start = Vec2{ i, row_i };
            }
            if (std.mem.indexOf(u8, row, "E")) |i| {
                end = Vec2{ i, row_i };
            }
        }
        assert(@reduce(.And, start != null_pos));
        assert(@reduce(.And, end != null_pos));

        const steps = try findShortestPathSteps(height_map, start, end, allocator);
        try stdout.print("Fewest steps from start to end is {d}", .{steps});
    } else {
        var starts = std.ArrayList(Vec2).init(allocator);
        defer starts.deinit();
        var end = null_pos;
        for (height_map.rows.items) |row, row_i| {
            if (std.mem.indexOf(u8, row, "S")) |i| {
                try starts.append(Vec2{ i, row_i });
            }
            if (std.mem.indexOf(u8, row, "E")) |i| {
                end = Vec2{ i, row_i };
            }

            var first_i: usize = 0;
            while (std.mem.indexOf(u8, row[first_i..], "a")) |i| {
                try starts.append(Vec2{ first_i + i, row_i });
                if (first_i < row.len - 1) {
                    first_i += i + 1;
                } else {
                    break;
                }
            }
        }
        assert(@reduce(.And, end != null_pos));

        var least_steps: u64 = std.math.maxInt(u64);
        for (starts.items) |start, start_i| {
            dbgPrint("{d} ", .{start_i});
            const steps = try findShortestPathSteps(height_map, start, end, allocator);
            dbgPrint("{d}\n", .{steps});
            least_steps = @min(steps, least_steps);
        }
        try stdout.print("Shortest scenic route has {d} steps", .{least_steps});
    }

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
