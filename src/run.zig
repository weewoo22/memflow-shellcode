const mf = @import("./memflow.zig");

pub fn run(os_instance: *mf.OsInstance, exe_path: []const u8) !void {
    _ = exe_path;

    // %SystemRoot%\System32\win32kbase.sys
    var kernel_module_info: mf.ModuleInfo = undefined;
    // Search for kernel process
    try mf.tryError(
        mf.mf_osinstance_module_by_name(os_instance, mf.slice("win32kbase.sys"), &kernel_module_info),
        error.MemflowOSIntanceModuleByNameError,
    );

    // try mf.scanModuleForPattern(
    //     null,
    //     null,
    //     &comptime mf.byteSequence(.{
    //         // 48 8B C4 48 89 58 ?? 48 89 70 ?? 48 89 78 ?? 55 41 56 41 57 48 8D 68 ?? 48 81 EC D0 00 00 00
    //         0x48, 0x8B, 0xC4, 0x48, 0x89, 0x58, {},   0x48, 0x89, 0x70, {},   0x48, 0x89, 0x78,
    //         {},   0x55, 0x41, 0x56, 0x41, 0x57, 0x48, 0x8D, 0x68, {},   0x48, 0x81, 0xEC, 0xD0,
    //         0x00, 0x00, 0x00,
    //     }),
    // );
}
