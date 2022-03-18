const std = @import("std");

pub usingnamespace @cImport({
    @cInclude("memflow.h");
});

const logger = std.log.scoped(.memflow);

const memflow = @This();

/// Convert Zig character slice to a memflow FFI character slice
pub fn slice(s: []const u8) memflow.CSliceRef_u8 {
    return .{ .data = s.ptr, .len = s.len };
}

/// Wrap memflow error code as a Zig error type and log error
pub fn tryErrorLog(error_number: i32, @"error": ?anyerror, print: ?bool) !void {
    const should_print_log_err = print orelse true;

    if (error_number != 0) {
        if (should_print_log_err)
            memflow.log_errorcode(memflow.Level_Error, error_number);

        if (@"error") |err|
            return err;
    }
}

/// Wrap memflow error code as a Zig error type
pub fn tryError(error_number: i32, @"error": ?anyerror) !void {
    return try tryErrorLog(error_number, @"error", null);
}

/// Single byte token with either a specified or unspecified value
pub const ByteToken = union(enum) {
    /// Byte with a defined value
    byte: u8, // 0xAD
    /// Byte of any value
    wildcard, // "??"

    pub fn format(
        value: *const @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        return switch (value.*) {
            .byte => |token| std.fmt.format(writer, "0x{X:02}", .{token}),
            .wildcard => std.fmt.format(writer, "??", .{}),
        };
    }
};

/// Convert a tuple of ByteTokens values into a slice of ByteTokens
pub fn byteSequence(comptime values: anytype) [@typeInfo(@TypeOf(values)).Struct.fields.len]ByteToken {
    const ArgsType = @TypeOf(values);
    const args_type_info = @typeInfo(ArgsType);
    if (args_type_info != .Struct) {
        @compileError("Expected tuple, found " ++ @typeName(ArgsType));
    }

    const max_format_args = 64;
    const fields_info = args_type_info.Struct.fields;
    if (fields_info.len < 1) {
        @compileError("Byte patterns have a minimum length of 1");
    } else if (fields_info.len > max_format_args) {
        @compileError("Byte patterns have a maximum length of" ++ std.fmt.comptimePrint("{}", .{max_format_args}));
    }

    // Array of byte tokens to populate and return as a slice eventually
    var tokens: [fields_info.len]ByteToken = undefined;
    inline for (fields_info) |field_info, index| {
        tokens[index] = switch (field_info.field_type) {
            comptime_int => .{ .byte = @field(values, field_info.name) },
            void => .{ .wildcard = {} },
            else => @compileError("Can't use field of type " ++ @typeName(ArgsType) ++ " in byte pattern"),
        };
    }

    return tokens;
}

pub fn scanOSModuleForPattern(
    os_instance: *memflow.OsInstance,
    module_info: *memflow.ModuleInfo,
    search_sequence: []const ByteToken,
) !?usize {
    logger.debug("Scanning module \"{s}\" (0x{X}-0x{X}) for pattern {any}", .{
        module_info.name,
        module_info.base,
        module_info.base + module_info.size,
        search_sequence,
    });

    const RangeCallbackContext = struct {
        search_sequence: []const memflow.ByteToken,
        os_instance: *memflow.OsInstance,
        match_address: ?usize = null,
    };

    var callback_context = RangeCallbackContext{
        .search_sequence = search_sequence,
        .os_instance = os_instance,
    };

    memflow.mf_processinstance_virt_page_map_range(
        os_instance,
        // Don't merge any gaps in memory regions, only map contiguous pages inclusive to module
        @as(memflow.imem, 0),
        // Start mapping address ranges from the base address of the module to search within
        module_info.base,
        // Map until the end of the module (base address + module size)
        module_info.base + module_info.size,
        .{
            .context = &callback_context,
            .func = struct {
                pub fn callback(
                    range_context: ?*anyopaque,
                    memory_range: memflow.MemoryRange,
                ) callconv(.C) bool {
                    var context: *RangeCallbackContext = @ptrCast(
                        *RangeCallbackContext,
                        @alignCast(
                            @alignOf(*RangeCallbackContext),
                            range_context,
                        ),
                    );

                    // Address to start at when searching within target module
                    var current_address = memory_range._0;
                    // Address of end of current module memory range
                    const range_end_address = memory_range._0 + memory_range._1 - context.search_sequence.len;
                    logger.debug("Scanning memory segment 0x{X}-0x{X} (0x{X})", .{
                        current_address,
                        range_end_address,
                        range_end_address - memory_range._0,
                    });

                    const address_alignment = 1;

                    // Search between start and end of current module address range
                    while (current_address < range_end_address) : (current_address += address_alignment) {
                        for (context.search_sequence) |expected_byte, index| {
                            switch (expected_byte) {
                                .byte => {
                                    // Get the byte of memory at the current address
                                    var current_memory_byte: u8 = undefined;
                                    memflow.readRawInto(
                                        &current_memory_byte,
                                        context.process_instance,
                                        current_address + index,
                                    ) catch {
                                        std.debug.print(
                                            "Failed to read address 0x{X}\n",
                                            .{current_address},
                                        );
                                    };

                                    if ((ByteToken{ .byte = current_memory_byte }).byte != expected_byte.byte) {
                                        // All is good, break out of the current for loop
                                        break;
                                    }
                                },
                                .wildcard => {},
                            }

                            // If we've looped through and all tokens matched
                            if (index == context.search_sequence.len - 1) {
                                context.match_address = current_address;
                                logger.debug("Found pattern match at address 0x{X}", .{context.match_address});
                                return false;
                            }
                        }
                    }

                    return true;
                }
            }.callback,
        },
    );

    return callback_context.match_address;
}

/// Wrapper for memflow read_raw_into
pub fn readRawInto(
    object: anytype,
    process_instance: *memflow.ProcessInstance,
    virtual_address: usize,
) !void {
    const read_size = @sizeOf(@typeInfo(@TypeOf(object)).Pointer.child);

    try memflow.tryErrorLog(
        memflow.mf_processinstance_read_raw_into(
            process_instance,
            virtual_address,
            .{ .data = @ptrCast([*c]u8, object), .len = read_size },
        ),
        error.MemflowProcessInstanceReadRawIntoError,
        null,
    );
}

/// Wrapper for memflow write_raw
pub fn writeRaw(
    object: anytype,
    process_instance: *memflow.ProcessInstance,
    virtual_address: usize,
) !void {
    const write_size = @sizeOf(@typeInfo(@TypeOf(object)).Pointer.child);

    try memflow.tryErrorLog(
        memflow.mf_processinstance_write_raw(
            process_instance,
            virtual_address,
            .{ .data = @ptrCast([*c]u8, object), .len = write_size },
        ),
        error.MemflowProcessInstanceWriteRawError,
        true,
    );
}
