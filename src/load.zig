const mf = @import("./memflow.zig");

const logger = @import("./main.zig").logger;

pub fn load(os_instance: *mf.OsInstance, process_name: []const u8, dll_path: []const u8) !void {
    _ = dll_path;

    var target_process_instance: mf.ProcessInstance = undefined;

    // Search for the target process name
    try mf.tryError(
        mf.mf_osinstance_process_by_name(os_instance, mf.slice(process_name), &target_process_instance),
        error.MemflowOSIntanceProcessByNameError,
    );

    const target_process_info = mf.mf_processinstance_info(&target_process_instance) orelse {
        logger.err("Failed to find process. Are you sure it's running?", .{});
        return error.MemflowProcessInstanceInfoError;
    };
    logger.info("Found target injection process as PID {}", .{target_process_info.*.pid});
}
