const std = @import("std");

// Import C's time.h for ctime
const c = @cImport({
    @cInclude("time.h");
});

/// Parse a string, keeping only digit characters, and interpret it as an i64 timestamp.
/// If bigger than 2^31, divide by 10 until smaller.
fn parseTimestamp(bytes: []const u8) !i64 {
    var digitBuf = std.ArrayList(u8).init(std.heap.page_allocator);
    defer digitBuf.deinit();

    // Keep only digit characters
    for (bytes) |x| {
        if (x == '.') break;
        if (x >= '0' and x <= '9') {
            try digitBuf.append(x);
        }
    }

    if (digitBuf.items.len == 0) return 0;

    const parsed: i64 = std.fmt.parseInt(i64, digitBuf.items, 10) catch 0;

    var val = parsed;
    const limit: i64 = 1 << 31;
    while (val > limit) {
        val = @divTrunc(val, 10);
    }

    return val;
}
fn formatUnixTimeC(timestamp: i64) ![]const u8 {
    var t: c.time_t = @intCast(timestamp);

    const cstr = c.ctime(&t);
    if (cstr == null) return error.InvalidTime;

    const slice = std.mem.span(cstr);

    return slice;
}
pub fn printTS(t: i64) !void {
    const ts = try formatUnixTimeC(t);
    try std.io.getStdOut().writer().print("{d} {s}", .{ t, ts });
}

pub fn main() !void {
    // Prepare a general-purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    // Get CLI args
    var args = std.process.argsAlloc(allocator) catch return;
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printTS(std.time.timestamp());
    }

    for (args[1..]) |arg| {
        const t = try parseTimestamp(arg);
        try printTS(t);
    }
}
