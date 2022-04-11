const std = @import("std");

const Pkg = std.build.Pkg;

const pkgs = struct {
    pub const win32 = Pkg{
        .name = "win32",
        .path = .{ .path = "./libs/zigwin32/win32.zig" },
    };
};

pub fn build(builder: *std.build.Builder) void {
    const target = builder.standardTargetOptions(.{});
    const mode = builder.standardReleaseOptions();

    const memflow_shell = builder.addExecutable("memflow-shell", "src/main.zig");
    memflow_shell.setTarget(target);
    memflow_shell.addPackagePath("args", "./libs/zig-args/args.zig");
    memflow_shell.setBuildMode(mode);
    memflow_shell.install();
    memflow_shell.linkLibC();
    memflow_shell.linkSystemLibrary("memflow_ffi"); // libmemflow_ffi.so

    const test_dll = builder.addSharedLibrary("test-dll", "src/test_dll.zig", .unversioned);
    test_dll.setTarget(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
    });
    test_dll.setBuildMode(mode);
    test_dll.addPackage(pkgs.win32);
    test_dll.linkLibC();
    test_dll.linkSystemLibraryName("user32");
    test_dll.install();

    const test_exe = builder.addExecutable("test-exe", "src/test_exe.zig");
    test_exe.setTarget(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
    });
    test_exe.addPackage(pkgs.win32);
    test_exe.setBuildMode(mode);
    test_exe.install();

    const run_cmd = memflow_shell.run();
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
