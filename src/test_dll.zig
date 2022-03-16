const std = @import("std");

const win32 = @import("win32").everything;

fn main() void {
    _ = win32.AllocConsole();

    std.debug.print("Hello world\n", .{});
}

pub export fn DllMain(
    handle_instance: ?*anyopaque,
    reason: c_ulong,
    reserved: ?*anyopaque,
) callconv(.C) c_int {
    _ = handle_instance;
    _ = reason;
    _ = reserved;

    switch (reason) {
        win32.DLL_PROCESS_ATTACH => {
            _ = std.Thread.spawn(.{}, main, .{}) catch unreachable;
        },
        else => {},
    }

    return 1;
}
