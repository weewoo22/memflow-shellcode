const std = @import("std");

pub const logger = std.log.scoped(.@"memflow-shell");
pub const log_level: std.log.Level = .debug;

const mf = @import("./memflow.zig");

pub fn main() !void {
    var inventory: *mf.Inventory = undefined;
    var connector_instance: mf.ConnectorInstance = undefined;
    var os_instance: mf.OsInstance = undefined;
    var process_instance: mf.ProcessInstance = undefined;

    // Initialize memflow logging
    mf.log_init(mf.Level_Info);

    // Create a connector inventory by scanning default and compiled-in paths
    // If it returns a null pointer treat this as an error in being unable to scan inventory paths
    inventory = mf.inventory_scan() orelse return error.MemflowInventoryScanError;

    // Create a new memflow connector instance from the current inventory of plugins (using KVM)
    try mf.tryError(
        mf.inventory_create_connector(inventory, "kvm", "", &connector_instance),
        error.MemflowInventoryCreateConnectorError,
    );
    // Now using the KVM connector instance create an OS instance (using win32)
    try mf.tryError(
        mf.inventory_create_os(inventory, "win32", "", &connector_instance, &os_instance),
        error.MemflowInventoryCreateOSError,
    );

    // Search for the target process name
    try mf.tryError(
        mf.mf_osinstance_process_by_name(&os_instance, mf.slice("Notepad.exe"), &process_instance),
        error.MemflowOSIntanceProcessByNameError,
    );

    const target_process_info = mf.mf_processinstance_info(&process_instance) orelse {
        logger.err("Failed to find process. Are you sure it's running?", .{});
        return error.MemflowProcessInstanceInfoError;
    };
    logger.info("Found process as PID {}", .{target_process_info.*.pid});
}
