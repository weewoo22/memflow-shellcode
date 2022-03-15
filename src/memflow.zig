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
