const std = @import("std");

pub const logger = std.log.scoped(.@"memflow-shell");
pub const log_level: std.log.Level = .debug;

const @"args-parser" = @import("args");

const mf = @import("./memflow.zig");

const load = @import("./load.zig").load;
const run = @import("./run.zig").run;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Memflow singletons
    var connector_inventory: *mf.Inventory = undefined;
    var connector_instance: mf.ConnectorInstance = undefined;
    var os_instance: mf.OsInstance = undefined;

    const Subcommand = union(enum) {
        load: struct {
            process: ?[]const u8 = null,
            dll: ?[]const u8 = null,

            pub const shorthands = .{
                .p = "process",
                .d = "dll",
            };
        },
        run: struct {
            exe: ?[]const u8 = null,

            pub const shorthands = .{
                .e = "exe",
            };
        },
    };

    const options = @"args-parser".parseWithVerbForCurrentProcess(
        struct {},
        Subcommand,
        allocator,
        .print,
    ) catch return 1;
    defer options.deinit();

    // Initialize memflow logging
    mf.log_init(mf.Level_Info);

    // Create a connector inventory by scanning default and compiled-in paths
    // If it returns a null pointer treat this as an error in being unable to scan inventory paths
    connector_inventory = mf.inventory_scan() orelse return mf.MemflowError.InventoryScanFailed;

    // Create a new memflow connector instance from the current inventory of plugins (using KVM)
    try mf.tryError(
        mf.inventory_create_connector(connector_inventory, "kvm", "", &connector_instance),
        mf.MemflowError.InventoryCreateConnectorError,
    );
    // Now using the KVM connector instance create an OS instance (using win32)
    try mf.tryError(
        mf.inventory_create_os(connector_inventory, "win32", "", &connector_instance, &os_instance),
        mf.MemflowError.InventoryCreateOSFailed,
    );

    var subcommand: Subcommand = undefined;

    if (options.verb) |verb| {
        subcommand = verb;
    } else {
        logger.err("Subcommand required", .{});
        return 1;
    }

    switch (subcommand) {
        // Forcefully load kernel driver or DLL
        .load => |opts| {
            var target_process_name: []const u8 = undefined;
            var injection_dll_path: []const u8 = undefined;

            if (opts.process) |process_name| {
                target_process_name = process_name;
            } else {
                logger.err("-p/--process is required", .{});
                return 1;
            }
            if (opts.dll) |dll_path| {
                injection_dll_path = dll_path;
            } else {
                logger.err("-d/--dll is required", .{});
                return 1;
            }

            load(allocator, &os_instance, target_process_name, injection_dll_path) catch |err| {
                if (err == mf.MemflowError.ProcessNameLookupFailed) {
                    logger.err("Unable to find target injection process with name \"{s}\". " ++
                        "Are you sure it's running?", .{target_process_name});
                    return 1;
                }

                return err;
            };
        },
        // Run usermode executable process
        .run => |opts| {
            var exe_path: []const u8 = undefined;
            if (opts.exe) |opt_exe| {
                exe_path = opt_exe;
            } else {
                logger.err("-e/--exe is required", .{});
                return 1;
            }

            try run(allocator, &os_instance, exe_path);
        },
    }

    return 0;
}
