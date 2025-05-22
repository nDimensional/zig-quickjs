const std = @import("std");

const quickjs = @import("quickjs");

pub fn main() !void {
    std.log.info("WOW", .{});
}

export fn add(a: u32, b: u32) u32 {
    return a + b;
}
