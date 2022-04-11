const std = @import("std");

pub fn main() !void {
    std.debug.print(
        \\Hello world!
        \\
        \\Press enter to exit...
        \\
    , .{});

    _ = try std.io.getStdIn().reader().readByte();
}
