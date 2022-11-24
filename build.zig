const std = @import("std");
const fmt = std.fmt;

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // Compile only the selected day's solution to the executable
    const day = b.option(i32, "day", "Day to compile") orelse -1;
    if (day < 0) {
        @panic("Please supply -Dday=n to the build command");
    }
    const prefix = if (day < 10) "0" else "";
    const source_path = fmt.allocPrint(b.allocator, "src/day{s}{d}.zig", .{ prefix, day }) catch
        @panic("Source path allocPrint failed");
    defer b.allocator.free(source_path);

    const exe = b.addExecutable("solution", source_path);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
