const std = @import("std");
const zeit = @import("zeit");

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

fn format(writer: anytype, timestamp: i64) !void {
    const allocator = std.heap.page_allocator;
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();
    const ns = try (zeit.Duration{ .seconds = @intCast(timestamp) }).inNanoseconds();
    const local = try zeit.local(allocator, &env);
    const t = (zeit.Instant{ .timestamp = ns, .timezone = &local }).time();
    _ = try t.strftime(writer, "%Y-%m-%d %H:%M:%S");
}

test format {
    const allocator = std.heap.page_allocator;
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const w = buf.writer();
    try format(w, 1737228748);
    try std.testing.expectEqualSlices(
        u8,
        try buf.toOwnedSlice(),
        "2025-01-18 09:32:28",
    );
}

pub fn printTS(t: i64) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{d} ", .{t});
    try format(stdout, t);
    _ = try stdout.write("\n");
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
