const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day08.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

fn getPart(allocator: Allocator) !u32 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try std.fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    return part;
}

const MarkedTrees = std.AutoHashMap(u64, void);

fn packTree(row: usize, col: usize) u64 {
    assert(row <= 0xFFFF_FFFF);
    assert(col <= 0xFFFF_FFFF);

    return (@as(u64, row) << 32) | @as(u64, col);
}

fn markTree(row: usize, col: usize, marked_trees: *MarkedTrees) !void {
    const tree =
        packTree(row, col);

    // dbgPrint("mark {d} {d}\n", .{ tree >> 32, tree & 0xFFFF_FFFF });

    // Just clobber as this is a set
    try marked_trees.put(tree, {});
}

const TreeGrid = struct {
    const Self = @This();

    trees: std.ArrayList(std.ArrayList(u8)),
    allocator: Allocator,

    fn init(allocator: Allocator) Self {
        return Self{
            .trees = std.ArrayList(std.ArrayList(u8)).init(allocator),
            .allocator = allocator,
        };
    }

    fn width(self: *const Self) usize {
        return self.trees.items[0].items.len;
    }

    fn height(self: *const Self) usize {
        return self.trees.items.len;
    }

    fn isOnEdge(self: *const Self, row: usize, col: usize) bool {
        return (row == 0) or (row == self.width() - 1) or (col == 0) or (col == self.height() - 1);
    }

    fn addRow(self: *Self, row: []const u8) !void {
        var row_mem = std.ArrayList(u8).init(self.allocator);

        try row_mem.resize(row.len);
        std.mem.copy(u8, row_mem.items, row);

        try self.trees.append(row_mem);
    }

    fn deinit(self: *const Self) void {
        for (self.trees.items) |row| {
            row.deinit();
        }
        self.trees.deinit();
    }

    fn peek(self: *const Self, row: usize, col: usize) u8 {
        return self.trees.items[row].items[col];
    }
};

fn markVisibleTrees(grid: TreeGrid, marked_trees: *MarkedTrees) !void {
    var row: usize = 0;
    while (row < grid.height()) : (row += 1) {
        var col: usize = 0;
        while (col < grid.width()) : (col += 1) {
            const ref_height = grid.peek(row, col);

            // Edges are always visible
            var visible = grid.isOnEdge(row, col);
            if (!visible) {
                var left_visible = true;
                var i: usize = col;
                while (i > 0) : (i -= 1) {
                    if (grid.peek(row, i - 1) >= ref_height) {
                        left_visible = false;
                        break;
                    }
                }
                visible = visible or left_visible;
            }
            if (!visible) {
                var right_visible = true;
                var i: usize = col + 1;
                while (i < grid.width()) : (i += 1) {
                    if (grid.peek(row, i) >= ref_height) {
                        right_visible = false;
                        break;
                    }
                }
                visible = visible or right_visible;
            }
            if (!visible) {
                var top_visible = true;
                var i: usize = row;
                while (i > 0) : (i -= 1) {
                    if (grid.peek(i - 1, col) >= ref_height) {
                        top_visible = false;
                        break;
                    }
                }
                visible = visible or top_visible;
            }
            if (!visible) {
                var bottom_visible = true;
                var i: usize = row + 1;
                while (i < grid.height()) : (i += 1) {
                    if (grid.peek(i, col) >= ref_height) {
                        bottom_visible = false;
                        break;
                    }
                }
                visible = visible or bottom_visible;
            }
            if (visible) {
                try markTree(row, col, marked_trees);
            }
        }
    }
}

fn scenicScore(row: usize, col: usize, grid: TreeGrid) u64 {
    assert(!grid.isOnEdge(row, col));

    const ref_height = grid.peek(row, col);

    // Score is multiplicative and we won't take the edges
    var score: u64 = 1;
    {
        var visible_trees: usize = 0;
        var i: usize = col;
        while (i > 0) : (i -= 1) {
            const other = grid.peek(row, i - 1);
            if (other < ref_height) {
                visible_trees += 1;
            } else {
                visible_trees += 1;
                break;
            }
        }
        // dbgPrint("{d} ", .{visible_trees});
        score *= @max(visible_trees, 1);
    }
    {
        var visible_trees: usize = 0;
        var i: usize = col + 1;
        while (i < grid.width()) : (i += 1) {
            const other = grid.peek(row, i);
            if (other < ref_height) {
                visible_trees += 1;
            } else {
                visible_trees += 1;
                break;
            }
        }
        // dbgPrint("{d} ", .{visible_trees});
        score *= @max(visible_trees, 1);
    }
    {
        var visible_trees: usize = 0;
        var i: usize = row;
        while (i > 0) : (i -= 1) {
            const other = grid.peek(i - 1, col);
            if (other < ref_height) {
                visible_trees += 1;
            } else {
                visible_trees += 1;
                break;
            }
        }
        // dbgPrint("{d} ", .{visible_trees});
        score *= @max(visible_trees, 1);
    }
    {
        var visible_trees: usize = 0;
        var i: usize = row + 1;
        while (i < grid.height()) : (i += 1) {
            const other = grid.peek(i, col);
            if (other < ref_height) {
                visible_trees += 1;
            } else {
                visible_trees += 1;
                break;
            }
        }
        // dbgPrint("{d} ", .{visible_trees});
        score *= @max(visible_trees, 1);
    }
    // dbgPrint(" = {d}\n", .{score});

    return score;
}

fn highestScenicScore(grid: TreeGrid) u64 {
    // Just skip the edges as their score will be 0
    var best_score: u64 = 0;
    var row: usize = 1;
    while (row < grid.height() - 1) : (row += 1) {
        var col: usize = 1;
        while (col < grid.width() - 1) : (col += 1) {
            const score = scenicScore(row, col, grid);
            if (score > best_score) {
                best_score = score;
            }
        }
    }
    return best_score;
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

    var grid = TreeGrid.init(allocator);
    defer grid.deinit();

    var lines = std.mem.split(u8, input_txt, line_ending);
    while (lines.next()) |line| {
        try grid.addRow(line);
    }
    assert(grid.trees.items.len > 0);
    assert(grid.trees.items[0].items.len > 0);

    if (part == 1) {
        var marked_trees: MarkedTrees = MarkedTrees.init(allocator);
        defer marked_trees.deinit();

        try markVisibleTrees(grid, &marked_trees);

        try stdout.print("{d} trees are visible", .{marked_trees.count()});
    } else {
        const score = highestScenicScore(grid);

        try stdout.print("The highest possible scenic score is {d}", .{score});
    }

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
