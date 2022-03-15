const std = @import("std");

pub fn build(builder: *std.build.Builder) void {
    const target = builder.standardTargetOptions(.{});
    const mode = builder.standardReleaseOptions();

    const exe = builder.addExecutable("memflow-shell", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    exe.linkLibC();
    exe.linkSystemLibrary("memflow_ffi"); // libmemflow_ffi.so

    const run_cmd = exe.run();
    run_cmd.step.dependOn(builder.getInstallStep());
    if (builder.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = builder.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = builder.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = builder.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
