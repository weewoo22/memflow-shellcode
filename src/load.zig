const std = @import("std");

const mf = @import("./memflow.zig");

const logger = @import("./main.zig").logger;

pub fn load(
    allocator: std.mem.Allocator,
    os_instance: *mf.OsInstance,
    process_name: []const u8,
    dll_path: []const u8,
) !void {
    logger.info("Using DLL at path \"{s}\"", .{dll_path});

    const dll_file: std.fs.File = try std.fs.cwd().openFile(dll_path, .{});
    defer dll_file.close();

    const dll_data = try dll_file.readToEndAlloc(allocator, 0x1000000);
    defer allocator.free(dll_data);

    logger.info("DLL is {} bytes in size", .{dll_data.len});

    var target_process_instance: mf.ProcessInstance = undefined;

    // Search for the target process name
    try mf.tryError(
        mf.mf_osinstance_process_by_name(os_instance, mf.slice(process_name), &target_process_instance),
        mf.MemflowError.ProcessNameLookupFailed,
    );

    const target_process_info = mf.mf_processinstance_info(&target_process_instance) orelse {
        return mf.MemflowError.ProcessInfoLookupFailed;
    };
    logger.info("Found target process as PID {}", .{target_process_info.*.pid});
}
