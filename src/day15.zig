const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day15.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

fn getPart(allocator: Allocator) !u32 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try std.fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    return part;
}

const Vec2i = @Vector(2, i32);
const Sensor = struct {
    pos: Vec2i,
    closest_beacon: Vec2i,
    beacon_dist: i32,
};

// Signed to match inputs, but will be >=0
fn manhattanDistance(from: Vec2i, to: Vec2i) i32 {
    const diff = to - from;
    // Is there really no built-in integer abs?
    return @reduce(.Add, @max(diff, -diff));
}

// parses [A-Z ].* x=([0-9].*), y=([0-9].*)
fn parseCoord(input: []const u8) !Vec2i {
    // First ends in x value, second is y value
    var prefixx_y = std.mem.split(u8, input, ", y=");

    // Second is x value
    var prefixx = std.mem.split(u8, prefixx_y.next().?, "x=");
    _ = prefixx.next().?;

    var x = try std.fmt.parseInt(i32, prefixx.next().?, 10);
    var y = try std.fmt.parseInt(i32, prefixx_y.next().?, 10);

    return Vec2i{
        x,
        y,
    };
}

fn parseInput(allocator: Allocator) !std.ArrayList(Sensor) {
    var sensors = std.ArrayList(Sensor).init(allocator);
    var lines = std.mem.split(u8, input_txt, line_ending);
    while (lines.next()) |line| {
        // First is sensor, second is beacon
        var sensor_beacon = std.mem.split(u8, line, ": ");

        const pos = try parseCoord(sensor_beacon.next().?);
        const beacon = try parseCoord(sensor_beacon.next().?);
        const beacon_dist = manhattanDistance(pos, beacon);

        try sensors.append(Sensor{
            .pos = pos,
            .closest_beacon = beacon,
            .beacon_dist = beacon_dist,
        });
    }

    return sensors;
}

fn rangeStartLessThan(_: void, a: Vec2i, b: Vec2i) bool {
    return a[0] < b[0];
}

fn knownRanges(sensors: []const Sensor, y: i32, allocator: Allocator) !std.ArrayList(Vec2i) {
    // [start,end) on x-axis
    var known_ranges = std.ArrayList(Vec2i).init(allocator);

    // Fill all known ranges on the row
    try known_ranges.ensureTotalCapacity(sensors.len);
    for (sensors) |sensor| {
        const pos_closest_to_sensor = Vec2i{ sensor.pos[0], y };
        const dist = manhattanDistance(pos_closest_to_sensor, sensor.pos);
        if (dist <= sensor.beacon_dist) {
            var diff_to_beacon_dist = sensor.beacon_dist - dist;
            try known_ranges.append(Vec2i{
                sensor.pos[0] - diff_to_beacon_dist,
                sensor.pos[0] + diff_to_beacon_dist + 1,
            });
        }
    }

    // Remove overlap from ranges
    {
        var i: usize = 0;
        while (i < known_ranges.items.len - 1) : (i += 1) {
            // Sort remaining ranges in case the effective order changes
            std.sort.sort(Vec2i, known_ranges.items[i..], {}, rangeStartLessThan);

            const first = known_ranges.items[i];
            if (first[1] - first[0] == 0) {
                continue;
            }

            var j: usize = i + 1;
            while (j < known_ranges.items.len) : (j += 1) {
                // Change first to keep order valid
                var second = &known_ranges.items[j];

                assert(first[0] <= second.*[0]);

                if (second.*[1] - second.*[0] == 0) {
                    continue;
                }

                if (first[1] > second.*[0]) {
                    second.*[0] = @min(first[1], second.*[1]);
                }
            }
        }
    }

    // Concatenate by removing 0 ranges and joining ranges that touch
    var i: usize = 0;
    while (i < known_ranges.items.len - 1) {
        var first = &known_ranges.items[i];
        var second = &known_ranges.items[i + 1];
        if (first.*[1] == second.*[0]) {
            first.*[1] = second.*[1];
            second.*[0] = second.*[1];
        }
        if (second.*[0] == second.*[1]) {
            _ = known_ranges.orderedRemove(i + 1);
        } else {
            i += 1;
        }
    }

    return known_ranges;
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

    const sensors = try parseInput(allocator);
    defer sensors.deinit();

    if (part == 1) {
        // const target_row = 10; // Test input
        const target_row = 2_000_000; // Personal input

        const known_ranges = try knownRanges(sensors.items, target_row, allocator);
        defer known_ranges.deinit();

        // Count squares in the unique ranges
        var count: i32 = 0;
        for (known_ranges.items) |range| {
            count += range[1] - range[0];
        }

        // Remove all unique beacons in the row as those are included in the ranges
        var known_beacons = std.AutoHashMap(i32, void).init(allocator);
        defer known_beacons.deinit();
        for (sensors.items) |sensor| {
            if (sensor.closest_beacon[1] == target_row and !known_beacons.contains(sensor.closest_beacon[0])) {
                try known_beacons.put(sensor.closest_beacon[0], {});
                count -= 1;
            }
        }

        try stdout.print("{d} positions cannot contain a beacon", .{count});
    } else {
        // const max_coord = 20; // Test input
        const max_coord = 4_000_000; // Personal input

        // TODO:
        // This is 4M iterations of non-trivial work with the proper input.
        // Is there a way to skip rows during the loop based on the current one?
        // Or is the idea of actually finding the ranges for each row bad?
        // Sorting multiple times in knownRanges is also not great but it doesn't
        // seem like the main problem here.
        var row: i32 = 0;
        while (row < max_coord) : (row += 1) {
            const known_ranges = try knownRanges(sensors.items, row, allocator);
            defer known_ranges.deinit();
            // Check we don't have multiple choices
            assert(known_ranges.items.len > 0);

            if (known_ranges.items.len > 1) {
                // Check we don't have multiple choices
                const first_range = known_ranges.items[0];
                const last_range = known_ranges.items[known_ranges.items.len - 1];
                assert(first_range[0] <= 0 and last_range[1] >= max_coord);

                var location_found = false;
                var i: usize = 0;
                while (i < known_ranges.items.len - 1) : (i += 1) {
                    const first = known_ranges.items[i];
                    const second = known_ranges.items[i + 1];
                    // We'd have multiple choices
                    assert(second[0] == first[1] + 1);
                    const candidate = first[1];
                    if (candidate >= 0 and candidate <= max_coord) {
                        // Check we didn't find another solution
                        assert(!location_found);
                        location_found = true;

                        // Continue to check we won't find another solution
                        const tuning_frequency = @intCast(u64, candidate) * 4_000_000 + @intCast(u64, row);

                        try stdout.print("Tuning frequency for the distress beacon is {d}", .{tuning_frequency});
                    }
                }
            } else {
                // Assume the signal is not on the edge of the area
                const range = known_ranges.items[0];
                assert(range[0] <= 0 and range[1] >= max_coord);
            }
        }
    }

    // Make sure we end with a newline
    try stdout.print("\n", .{});

    try stdout.print("Took {d}ms\n ", .{timer.read() / std.time.ns_per_ms});

    try bw.flush(); // don't forget to flush!
}
