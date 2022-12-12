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
    signal_point: Vec2,

    fn init(allocator: Allocator) Self {
        return Self{
            .rows = std.ArrayList([]const u8).init(allocator),
            .width = 0,
            .height = 0,
            .signal_point = null_pos,
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

    for (height_map.rows.items) |row, row_i| {
        if (std.mem.indexOf(u8, row, "E")) |i| {
            height_map.signal_point = Vec2{ i, row_i };
        }
    }
    assert(@reduce(.And, height_map.signal_point != null_pos));

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

    // Check height diff from neighbor as that is the height diff from low to high
    // while traversing high to low
    if (heightDiff(neighbor_height, self_height) <= 1) {
        if (distances.get(neighbor_pos).? == not_seen_distance) {
            try queue.writeItem(neighbor_pos);
        }

        try updateDistance(neighbor_pos, new_distance, distances);
    }
}

fn findShortestPathSteps(height_map: HeightMap, allocator: Allocator) !DistanceMap {
    var queue = PosQueue.init(allocator);
    defer queue.deinit();

    var distances = DistanceMap.init(allocator);

    {
        var j: usize = 0;
        while (j < height_map.height) : (j += 1) {
            var i: usize = 0;
            while (i < height_map.width) : (i += 1) {
                try distances.put(Vec2{ i, j }, not_seen_distance);
            }
        }
    }
    try distances.put(height_map.signal_point, 0);

    try queue.writeItem(height_map.signal_point);

    while (queue.readItem()) |pos| {
        assert(distances.get(pos).? < not_seen_distance);

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

    return distances;
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

    const height_map = try parseInput(allocator);
    defer height_map.deinit();

    // Fill out all shortest paths from the signal point to avoid duplicate work
    // in part 2
    // Distances are not really symmertric with the neighbor height limit, but we can
    // traverse while checking the height delta from neighbor to the current square
    // to fill out the distances from lowland to the signal point
    var distances = try findShortestPathSteps(height_map, allocator);
    defer distances.deinit();

    if (part == 1) {
        var start = null_pos;
        for (height_map.rows.items) |row, row_i| {
            if (std.mem.indexOf(u8, row, "S")) |i| {
                start = Vec2{ i, row_i };
            }
        }
        assert(@reduce(.And, start != null_pos));

        const steps = distances.get(start).?;
        try stdout.print("Fewest steps from start to end is {d}", .{steps});
    } else {
        var starts = std.ArrayList(Vec2).init(allocator);
        defer starts.deinit();

        for (height_map.rows.items) |row, row_i| {
            if (std.mem.indexOf(u8, row, "S")) |i| {
                try starts.append(Vec2{ i, row_i });
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

        var least_steps: u64 = std.math.maxInt(u64);
        for (starts.items) |start| {
            const steps = distances.get(start).?;
            least_steps = @min(steps, least_steps);
        }
        try stdout.print("Shortest scenic route has {d} steps", .{least_steps});
    }

    // Make sure we end with a newline
    try stdout.print("\n", .{});

    try stdout.print("Took {d}ms\n ", .{timer.read() / std.time.ns_per_ms});

    try bw.flush(); // don't forget to flush!
}
