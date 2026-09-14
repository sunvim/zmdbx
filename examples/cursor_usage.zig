// 游标使用示例
// 演示如何使用游标遍历数据库

const std = @import("std");
const zmdbx = @import("zmdbx");
const util = @import("util.zig");

/// 示例用的数据库路径。跑完就删，不在工作目录里留数据。
const db_path = "./testdb";

pub fn main() !void {
    std.debug.print("=== MDBX 游标使用示例 ===\n\n", .{});

    // 从干净状态开始；结束时删除（包括出错提前返回的情况）
    util.deleteTree(db_path);
    defer util.deleteTree(db_path);

    // 创建并打开环境
    var env = try zmdbx.Env.init();
    defer env.deinit();
    try env.open(db_path, zmdbx.EnvFlagSet.init(.{}), 0o644);

    // 写入测试数据
    std.debug.print("1. 写入测试数据...\n", .{});
    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        var db_flags = zmdbx.DBFlagSet.init(.{});
        db_flags.insert(.create);
        const dbi = try txn.openDBI(null, db_flags);

        const put_flags = zmdbx.PutFlagSet.init(.{});
        try txn.put(dbi, "user:001", "Alice", put_flags);
        try txn.put(dbi, "user:002", "Bob", put_flags);
        try txn.put(dbi, "user:003", "Charlie", put_flags);
        try txn.put(dbi, "user:004", "David", put_flags);
        try txn.put(dbi, "user:005", "Eve", put_flags);

        try txn.commit();
        std.debug.print("   写入 5 条用户数据\n\n", .{});
    }

    // 使用游标遍历
    std.debug.print("2. 使用游标遍历所有数据...\n", .{});
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 遍历所有记录
        var result = try cursor.get(null, null, .first);
        var count: usize = 0;

        while (true) {
            count += 1;
            std.debug.print("   [{d}] key: {s}, value: {s}\n", .{ count, result.key.toBytes(), result.data.toBytes() });

            result = cursor.get(null, null, .next) catch |err| {
                if (err == error.NotFound) break;
                return err;
            };
        }

        std.debug.print("\n   共遍历 {d} 条记录\n\n", .{count});
    }

    // 使用游标查找特定范围
    std.debug.print("3. 查找 key >= 'user:003' 的记录...\n", .{});
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 定位到 >= user:003 的位置
        var result = try cursor.get("user:003", null, .set_range);
        var count: usize = 0;

        while (true) {
            count += 1;
            std.debug.print("   [{d}] key: {s}, value: {s}\n", .{ count, result.key.toBytes(), result.data.toBytes() });

            result = cursor.get(null, null, .next) catch |err| {
                if (err == error.NotFound) break;
                return err;
            };
        }

        std.debug.print("\n   找到 {d} 条匹配记录\n", .{count});
    }

    std.debug.print("\n✓ 游标使用示例完成！\n", .{});
    std.debug.print("  （示例数据库已删除，工作目录保持干净）\n", .{});
}
