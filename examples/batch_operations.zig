// 批量操作示例
// 演示如何高效地进行批量数据插入和删除

const std = @import("std");
const zmdbx = @import("zmdbx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== MDBX 批量操作示例 ===\n\n", .{});

    // 创建并打开环境
    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setGeometry(.{
        .lower = 1024 * 1024,
        .now = 100 * 1024 * 1024,
        .upper = 1024 * 1024 * 1024,
        .growth_step = 10 * 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    try env.open("./testdb_batch", zmdbx.EnvFlagSet.init(.{}), 0o644);

    const batch_size = 10000;

    // 批量插入
    std.debug.print("1. 批量插入 {d} 条记录...\n", .{batch_size});
    const start_insert = std.time.milliTimestamp();

    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        var db_flags = zmdbx.DBFlagSet.init(.{});
        db_flags.insert(.create);
        const dbi = try txn.openDBI(null, db_flags);

        var i: usize = 0;
        while (i < batch_size) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
            defer allocator.free(key);

            const value = try std.fmt.allocPrint(allocator, "value_{d}", .{i});
            defer allocator.free(value);

            try txn.put(dbi, key, value, zmdbx.PutFlagSet.init(.{}));

            if ((i + 1) % 1000 == 0) {
                std.debug.print("   已插入 {d} 条...\r", .{i + 1});
            }
        }

        try txn.commit();
    }

    const insert_time = std.time.milliTimestamp() - start_insert;
    std.debug.print("\n   插入完成！耗时: {d}ms\n", .{insert_time});
    std.debug.print("   吞吐量: {d} ops/s\n\n", .{@divTrunc(batch_size * 1000, @as(usize, @intCast(insert_time)))});

    // 批量读取
    std.debug.print("2. 批量读取验证...\n", .{});
    const start_read = std.time.milliTimestamp();

    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));

        var i: usize = 0;
        while (i < batch_size) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
            defer allocator.free(key);

            _ = try txn.getBytes(dbi, key);

            if ((i + 1) % 1000 == 0) {
                std.debug.print("   已读取 {d} 条...\r", .{i + 1});
            }
        }
    }

    const read_time = std.time.milliTimestamp() - start_read;
    std.debug.print("\n   读取完成！耗时: {d}ms\n", .{read_time});
    std.debug.print("   吞吐量: {d} ops/s\n\n", .{@divTrunc(batch_size * 1000, @as(usize, @intCast(read_time)))});

    // 批量删除
    std.debug.print("3. 批量删除一半记录...\n", .{});
    const delete_count = batch_size / 2;
    const start_delete = std.time.milliTimestamp();

    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));

        var i: usize = 0;
        while (i < delete_count) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
            defer allocator.free(key);

            try txn.del(dbi, key, null);

            if ((i + 1) % 1000 == 0) {
                std.debug.print("   已删除 {d} 条...\r", .{i + 1});
            }
        }

        try txn.commit();
    }

    const delete_time = std.time.milliTimestamp() - start_delete;
    std.debug.print("\n   删除完成！耗时: {d}ms\n", .{delete_time});
    std.debug.print("   吞吐量: {d} ops/s\n", .{@divTrunc(delete_count * 1000, @as(usize, @intCast(delete_time)))});

    std.debug.print("\n✓ 批量操作示例完成！\n", .{});
}
