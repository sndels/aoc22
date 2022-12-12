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
    start: Vec2,
    end: Vec2,

    fn init(allocator: Allocator) Self {
        return Self{
            .rows = std.ArrayList([]const u8).init(allocator),
            .width = 0,
            .height = 0,
            .start = null_pos,
            .end = null_pos,
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

    for (rows.items) |row, row_i| {
        if (std.mem.indexOf(u8, row, "S")) |i| {
            height_map.start = Vec2{ i, row_i };
        }
        if (std.mem.indexOf(u8, row, "E")) |i| {
            height_map.end = Vec2{ i, row_i };
        }
    }
    assert(@reduce(.And, height_map.start != null_pos));
    assert(@reduce(.And, height_map.end != null_pos));

    return height_map;
}

fn updateDistance(pos: Vec2, new_distance: u64, distances: *DistanceMap) !void {
    assert(distances.contains(pos));

    dbgPrint("{d}\n", .{new_distance});
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
        try distances.put(height_map.start, 0);

        try queue.writeItem(height_map.start);

        var end_steps: u64 = std.math.maxInt(u64);
        while (queue.readItem()) |pos| {
            assert(distances.get(pos).? < not_seen_distance);

            if (@reduce(.And, pos == height_map.end)) {
                end_steps = distances.get(pos).?;
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

        try stdout.print("Fewest steps to end is {d}", .{end_steps});
    } else {
        try stdout.print("TODO", .{});
    }

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
