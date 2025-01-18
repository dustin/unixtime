const std = @import("std");

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

    var val: i64 = std.fmt.parseInt(i64, digitBuf.items, 10) catch 0;

    const limit: i64 = 1 << 31;
    while (val > limit) {
        val = @divTrunc(val, 10);
    }

    return val;
}

test parseTimestamp {
    const Expected = union(enum) {
        value: i64,
        err: anyerror,
    };

    const testCases = [_]struct {
        input: []const u8,
        expected: Expected,
    }{
        .{ .input = "1234", .expected = .{ .value = 1234 } },
        .{ .input = "1234.5", .expected = .{ .value = 1234 } },
        .{ .input = "abc", .expected = .{ .value = 0 } },
    };

    for (testCases) |testCase| {
        const actualOrErr = parseTimestamp(testCase.input);
        switch (testCase.expected) {
            .value => |expVal| {
                try std.testing.expectEqual(expVal, actualOrErr);
            },
            .err => |expErr| {
                try std.testing.expectError(expErr, actualOrErr);
            },
        }
    }
}

fn format(timestamp: i64) ![]const u8 {
    var t: c.time_t = @intCast(timestamp);

    const cstr = c.ctime(&t);
    if (cstr == null) return error.InvalidTime;

    return std.mem.span(cstr);
}

test format {
    try std.testing.expectEqualSlices(u8, "Sat Jan 18 09:32:28 2025\n", try format(1737228748));
}

pub fn printTS(t: i64) !void {
    try std.io.getStdOut().writer().print("{d} {s}", .{ t, try format(t) });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

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
