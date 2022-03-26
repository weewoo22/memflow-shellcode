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
            .byte => |token| std.fmt.format(writer, "0x{X:0>2}", .{token}),
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

/// Scan kernel module for pattern
pub fn scanOSModuleForPattern(
    os_instance: *memflow.OsInstance,
    module_info: *memflow.ModuleInfo,
    search_sequence: []const ByteToken,
) !?usize {
    const module_end = module_info.base + module_info.size;
    logger.debug("Scanning module \"{s}\" with size of {} bytes (0x{X}-0x{X}) for pattern {any}", .{
        module_info.name,
        module_info.size,
        module_info.base,
        module_end,
        search_sequence,
    });

    const allocator: std.mem.Allocator = std.heap.page_allocator;

    // Allocate a byte array that's the size of the module being scanned
    var module_memory: []u8 = try allocator.alloc(u8, module_info.size);
    defer allocator.free(module_memory);

    // Read as much of the module's memory as possible (ignoring errors) into the allocated buffer
    try readOSRawInto(module_memory.ptr, module_memory.len, os_instance, module_info.base);

    var current_index: usize = 0;
    const address_alignment = 1; // TODO: make this a function parameter
    var match_offset: ?usize = null;

    // Search between the start and end of the copy of the module's memory
    outter: while (current_index < module_info.size - search_sequence.len) : (current_index += address_alignment) {
        for (search_sequence) |expected_byte, seq_index| {
            const current_byte = module_memory[current_index + seq_index];

            switch (expected_byte) {
                .byte => {
                    if ((ByteToken{ .byte = current_byte }).byte != expected_byte.byte) {
                        // Doesn't match, advance outter index by address_alignment and try again
                        break;
                    }
                },
                .wildcard => {},
            }

            // If all bytes matched all tokens at the end of looping
            if (seq_index == search_sequence.len - 1) {
                match_offset = current_index;
                logger.debug("Found a match", .{});
                break :outter;
            }
        }
    }

    return if (match_offset) |offset| module_info.base + offset else match_offset;
}

pub fn readOSRawInto(
    object: anytype,
    size: ?usize,
    os_instance: *memflow.OsInstance,
    virtual_address: usize,
) !void {
    const read_size = if (size) |s| s else @sizeOf(@typeInfo(@TypeOf(object)).Pointer.child);

    const read_status = memflow.mf_osinstance_read_raw_into(
        os_instance,
        virtual_address,
        .{ .data = @ptrCast([*c]u8, object), .len = read_size },
    );

    return switch (read_status) {
        0 => {},
        // TODO: add different read failures
        else => error.MemflowOSInstanceReadRawIntoUnknownError,
    };
}

pub fn writeOSRaw(object: anytype, os_instance: *memflow.OsInstance, virtual_address: usize) !void {
    _ = object;
    _ = os_instance;
    _ = virtual_address;
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
