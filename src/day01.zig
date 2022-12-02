const std = @import("std");
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input = @embedFile("inputs/day01.txt");

const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";
const double_line_ending = line_ending ++ line_ending;

pub fn main() !void {
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

    var total_calories = std.ArrayList(u32).init(allocator);
    defer total_calories.deinit();

    var elves = std.mem.split(u8, input, double_line_ending);
    while (elves.next()) |elf| {
        var foods = std.mem.split(u8, elf, line_ending);
        var elf_calories: u32 = 0;
        while (foods.next()) |food| {
            // Last element from the last elf seems to be empty
            if (food.len > 0) {
                const calories = try std.fmt.parseUnsigned(u32, food, 10);
                elf_calories += calories;
            }
        }
        total_calories.append(elf_calories) catch @panic("append failed");
    }

    std.sort.sort(u32, total_calories.items, {}, std.sort.desc(u32));

    var result: u32 = 0;
    if (part == 1) {
        result = total_calories.items[0];
    } else {
        const items = total_calories.items;
        result = items[0] + items[1] + items[2];
    }

    // Print result here
    try stdout.print("{d} calories", .{result});

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
