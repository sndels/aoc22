const std = @import("std");
const Allocator = std.mem.Allocator;
const LinesIter = std.mem.SplitIterator(u8);
const assert = std.debug.assert;
const dbgPrint = std.debug.print;
const builtin = @import("builtin");

const input_txt = @embedFile("inputs/day07.txt");
const line_ending = if (builtin.os.tag == .windows) "\r\n" else "\n";

fn getPart(allocator: Allocator) !u32 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    assert(args.len == 2);
    const part = try std.fmt.parseUnsigned(u32, args[1], 10);
    assert(part == 1 or part == 2);

    return part;
}

fn last(comptime T: type, array: *const std.ArrayList(T)) T {
    return array.items[array.items.len - 1];
}

const FSNodeType = enum { Dir, File };

const FSNode = struct {
    const Self = @This();

    node_type: FSNodeType,
    name: []const u8,
    children: std.ArrayList(usize),
    size: u64,

    fn init(node_type: FSNodeType, name: []const u8, allocator: Allocator) Self {
        return Self{
            .node_type = node_type,
            .name = name,
            .children = std.ArrayList(usize).init(allocator),
            .size = 0,
        };
    }

    fn deinit(self: *const Self) void {
        self.children.deinit();
    }

    fn findChild(self: *const Self, name: []const u8, nodes: *const std.ArrayList(FSNode)) ?usize {
        for (self.children.items) |child_i| {
            const child = &nodes.items[child_i];
            if (std.mem.eql(u8, child.name, name)) {
                return child_i;
            }
        }
        return null;
    }
};

const FSNodes = struct {
    const Self = @This();

    nodes: std.ArrayList(FSNode),

    fn init(allocator: Allocator) Self {
        return Self{
            .nodes = std.ArrayList(FSNode).init(allocator),
        };
    }

    fn deinit(self: *const Self) void {
        for (self.nodes.items) |node| {
            node.deinit();
        }
        self.nodes.deinit();
    }
};

fn handleCd(line: []const u8, working_directory_path: *std.ArrayList(usize), nodes: *std.ArrayList(FSNode)) !void {
    if (line[5] == '/') {
        working_directory_path.clearRetainingCapacity();
        try working_directory_path.append(0);
    } else if (line.len == 7 and std.mem.eql(u8, line[5..7], "..")) {
        _ = working_directory_path.pop();
    } else {
        const name = line[5..];

        const current_node_i = last(usize, working_directory_path);

        if (nodes.items[current_node_i].findChild(name, nodes)) |child_i| {
            assert(nodes.items[child_i].node_type == FSNodeType.Dir);
            try working_directory_path.append(child_i);
        } else {
            @panic("Expected all 'cd's to access previously listed folders");
        }
    }
}

fn handleLsOutput(line: []const u8, working_directory_path: *std.ArrayList(usize), nodes: *std.ArrayList(FSNode), allocator: Allocator) !void {
    const current_node_i = last(usize, working_directory_path);

    var parts = std.mem.split(u8, line, " ");
    var size_or_dir = parts.next().?;
    var name = parts.next().?;
    assert(parts.next() == null);

    if (std.mem.eql(u8, size_or_dir, "dir")) {
        if (nodes.items[current_node_i].findChild(name, nodes)) |child_i| {
            assert(nodes.items[child_i].node_type == FSNodeType.Dir);
        } else {
            const child_i = nodes.items.len;
            try nodes.append(FSNode.init(FSNodeType.Dir, name, allocator));
            try nodes.items[current_node_i].children.append(child_i);
        }
    } else {
        var size = try std.fmt.parseUnsigned(u64, size_or_dir, 10);
        if (nodes.items[current_node_i].findChild(name, nodes)) |child_i| {
            nodes.items[child_i].size = size;
        } else {
            const child_i = nodes.items.len;
            try nodes.append(FSNode.init(FSNodeType.File, name, allocator));
            try nodes.items[current_node_i].children.append(child_i);
            nodes.items[child_i].size = size;
        }
    }
}

fn printFS(node_i: usize, indent_level: usize, nodes: []const FSNode) void {
    const node = &nodes[node_i];

    {
        var i: usize = 0;
        while (i < indent_level) : (i += 1) {
            dbgPrint("  ", .{});
        }
    }

    switch (node.node_type) {
        FSNodeType.Dir => {
            dbgPrint("- {s} (dir, content_size={d})\n", .{ node.name, node.size });

            for (node.children.items) |child_i| {
                printFS(child_i, indent_level + 1, nodes);
            }
        },
        FSNodeType.File => {
            dbgPrint("- {s} (file, size={d})\n", .{ node.name, node.size });
        },
    }
}

fn fillDirSizes(node_i: usize, nodes: []FSNode) u64 {
    const node = &nodes[node_i];

    if (node.node_type == FSNodeType.File) {
        return node.size;
    }
    assert(node.node_type == FSNodeType.Dir);

    node.size = 0;
    for (node.children.items) |child_i| {
        node.size += fillDirSizes(child_i, nodes);
    }

    return node.size;
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

    var nodes_wrapper = FSNodes.init(allocator);
    defer nodes_wrapper.deinit();
    const nodes = &nodes_wrapper.nodes;

    try nodes.append(FSNode.init(FSNodeType.Dir, "/", allocator));

    var working_directory_path = std.ArrayList(usize).init(allocator);
    defer working_directory_path.deinit();
    try working_directory_path.append(0);

    var lines = std.mem.split(u8, input_txt, line_ending);
    while (lines.next()) |line| {
        if (line[0] == '$') {
            if (std.mem.eql(u8, line[2..4], "cd")) {
                try handleCd(line, &working_directory_path, nodes);
            } else if (std.mem.eql(u8, line[2..4], "ls")) {
                // Just skip, we assume we're in ls output if line doesn't start with $
            } else {
                @panic("Unknown command");
            }
        } else {
            // We're in 'ls' output if line doesn't start with '$'
            try handleLsOutput(line, &working_directory_path, nodes, allocator);
        }
    }

    _ = fillDirSizes(0, nodes.items);

    // printFS(0, 0, nodes.items);

    if (part == 1) {
        // No need to care about the tree structure as only a folder's size matters
        var size_sum: u64 = 0;
        for (nodes.items) |node| {
            if ((node.node_type == FSNodeType.Dir) and (node.size < 100_000)) {
                size_sum += node.size;
            }
        }

        try stdout.print("Sum of total sizes is {d}", .{size_sum});
    } else {
        const used_space = nodes.items[0].size;

        const total_space: u64 = 70_000_000;
        const required_space: u64 = 30_000_000;
        const space_to_free = required_space - (total_space - used_space);

        // No need to care about the tree structure here either as only a folder's size matters
        var smallest_suitable_size: u64 = 0xFFFF_FFFF_FFFF_FFFF;
        for (nodes.items) |node| {
            if ((node.node_type == FSNodeType.Dir) and
                (node.size > space_to_free) and (node.size < smallest_suitable_size))
            {
                smallest_suitable_size = node.size;
            }
        }

        try stdout.print("Size of the smallest suitable dir is {d}\n", .{smallest_suitable_size});
    }

    // Make sure we end with a newline
    try stdout.print("\n", .{});
    try bw.flush(); // don't forget to flush!
}
