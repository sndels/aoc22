const std = @import("std");
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input = @embedFile("inputs/day02.txt");

const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

pub fn value(play: u8) u64 {
    // Plays are A=1, B=1 and C=3 points each
    return play - 'A' + 1;
}

pub fn winningPlay(opponent_play: u8) u8 {
    // This could be (((opponent_play - 'A') + 1) % 3) + 'A' uf I wanted to be cute
    switch (opponent_play) {
        'A' => return 'B',
        'B' => return 'C',
        'C' => return 'A',
        else => @panic("Invalid opponent play"),
    }
}

pub fn losingPlay(opponent_play: u8) u8 {
    // This could be (((opponent_play - 'A') + 2) % 3) + 'A' if I wanted to be cute
    switch (opponent_play) {
        'A' => return 'C',
        'B' => return 'A',
        'C' => return 'B',
        else => @panic("Invalid opponent play"),
    }
}

pub fn choosePlay(opponent_play: u8, tactic: u8) u8 {
    switch (tactic) {
        'X' => return losingPlay(opponent_play),
        'Y' => return opponent_play,
        'Z' => return winningPlay(opponent_play),
        else => @panic("Invalid tactic"),
    }
}

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

    var rounds = std.mem.split(u8, input, line_ending);
    var score: u64 = 0;
    while (rounds.next()) |round| {
        // File ends in a newline
        if (round.len == 0) {
            break;
        }

        const opponent_play = round[0];

        const own_play = blk: {
            if (part == 1) {
                // Let's just use the same characters for both
                // (Well that was a clairvoyant call in part 1 :D)
                break :blk round[2] - 'X' + 'A';
            } else {
                break :blk choosePlay(opponent_play, round[2]);
            }
        };

        assert(own_play >= 'A' and own_play <= 'C');

        score += value(own_play);
        if (own_play == opponent_play) {
            score += 3;
        } else if (own_play == winningPlay(opponent_play)) {
            score += 6;
        }
    }

    // Print result here
    try stdout.print("Total score: {d}", .{score});

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
