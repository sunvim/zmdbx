// 基本使用示例
// 演示如何创建环境、打开数据库、插入和查询数据

const std = @import("std");
const zmdbx = @import("zmdbx");

pub fn main() !void {
    std.debug.print("=== MDBX 基本使用示例 ===\n\n", .{});

    // 1. 创建环境
    std.debug.print("1. 创建环境...\n", .{});
    var env = try zmdbx.Env.init();
    defer env.deinit();

    // 2. 设置数据库参数
    std.debug.print("2. 设置数据库参数...\n", .{});
    try env.setMaxdbs(10);
    try env.setGeometry(.{
        .lower = 1024 * 1024,      // 1MB 最小
        .now = 10 * 1024 * 1024,   // 10MB 初始
        .upper = 100 * 1024 * 1024, // 100MB 最大
        .growth_step = 1024 * 1024, // 1MB 增长步长
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    // 3. 打开环境
    std.debug.print("3. 打开数据库环境...\n", .{});
    try env.open("./testdb", zmdbx.EnvFlagSet.init(.{}), 0o644);

    // 4. 开始写事务
    std.debug.print("4. 开始写事务...\n", .{});
    var txn = try env.beginWriteTxn();
    defer txn.abort(); // 确保异常情况下事务被中止

    // 5. 打开数据库实例
    std.debug.print("5. 打开数据库实例...\n", .{});
    var db_flags = zmdbx.DBFlagSet.init(.{});
    db_flags.insert(.create);
    const dbi = try txn.openDBI(null, db_flags);

    // 6. 插入数据
    std.debug.print("6. 插入数据...\n", .{});
    const put_flags = zmdbx.PutFlagSet.init(.{});
    try txn.put(dbi, "name", "张三", put_flags);
    try txn.put(dbi, "age", "25", put_flags);
    try txn.put(dbi, "city", "北京", put_flags);
    std.debug.print("   插入了 3 条数据\n", .{});

    // 7. 查询数据
    std.debug.print("7. 查询数据...\n", .{});
    const name = try txn.getBytes(dbi, "name");
    const age = try txn.getBytes(dbi, "age");
    const city = try txn.getBytes(dbi, "city");

    std.debug.print("   name: {s}\n", .{name});
    std.debug.print("   age: {s}\n", .{age});
    std.debug.print("   city: {s}\n", .{city});

    // 8. 提交事务
    std.debug.print("8. 提交事务...\n", .{});
    try txn.commit();

    // 9. 验证数据已持久化
    std.debug.print("9. 验证数据持久化（新事务）...\n", .{});
    var read_txn = try env.beginReadTxn();
    defer read_txn.abort();

    const dbi2 = try read_txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));
    const verify_name = try read_txn.getBytes(dbi2, "name");
    std.debug.print("   验证读取: name = {s}\n", .{verify_name});

    std.debug.print("\n✓ 基本使用示例完成！\n", .{});
}
