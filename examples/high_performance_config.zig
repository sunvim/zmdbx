// 高性能 MDBX 配置示例
// 展示如何配置 MDBX 以实现最高写入速度 + 断电安全

const std = @import("std");
const zmdbx = @import("zmdbx");

/// 场景 1: 高性能日志系统 (推荐生产环境)
/// - 写入速度: ~150,000 ops/s
/// - 数据安全: 断电丢失 <30秒 或 <64MB 数据
/// - 进程崩溃: 100% 数据安全
pub fn setupHighPerformanceLog() !zmdbx.Env {
    var env = try zmdbx.Env.init();

    // 1. 设置几何参数 (大容量,快速增长)
    try env.setGeometry(.{
        .lower = 100 * 1024 * 1024, // 最小 100MB
        .now = 1024 * 1024 * 1024, // 初始 1GB
        .upper = 100 * 1024 * 1024 * 1024, // 最大 100GB
        .growth_step = 256 * 1024 * 1024, // 增长步长 256MB
        .shrink_threshold = -1, // 不自动收缩
        .pagesize = -1, // 使用系统默认页大小
    });

    // 2. 性能调优参数
    try env.setOption(.OptTxnDpLimit, 262144); // 事务脏页上限 4x (256K 页)
    try env.setOption(.OptTxnDpInitial, 16384); // 脏页初始分配 16x (16K 页)
    try env.setOption(.OptDpReserveLimit, 8192); // 脏页预留池 8x (8K 页)
    try env.setOption(.OptLooseLimit, 128); // 松散页缓存 2x (128 页)

    // 3. 同步策略 (容忍30秒数据丢失)
    try env.setSyncBytes(64 * 1024 * 1024); // 每 64MB 数据触发一次同步
    try env.setSyncPeriod(30 * 65536); // 每 30 秒触发一次同步

    // 4. 打开环境 (WRITE_MAP + SAFE_NOSYNC)
    try env.open("./log.mdbx", .write_map, 0o755);
    try env.setFlags(.safe_no_sync, true);

    return env;
}

/// 场景 2: 金融级别安全
/// - 写入速度: ~10,000 ops/s (SSD) / ~1,000 ops/s (HDD)
/// - 数据安全: 100% 断电保护
/// - 适用于: 金融交易、支付系统、用户账户
pub fn setupFinancialDatabase() !zmdbx.Env {
    var env = try zmdbx.Env.init();

    // 1. 中等容量,稳定增长
    try env.setGeometry(.{
        .lower = 50 * 1024 * 1024,
        .now = 500 * 1024 * 1024,
        .upper = 10 * 1024 * 1024 * 1024,
        .growth_step = 100 * 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    // 2. 保守的性能参数 (使用默认值)
    try env.setOption(.OptTxnDpLimit, 65536); // 默认值
    try env.setOption(.OptTxnDpInitial, 2048); // 2x 默认

    // 3. 完全同步模式 (SYNC_DURABLE)
    try env.open("./financial.mdbx", .defaults, 0o755);

    return env;
}

/// 场景 3: 混合模式 (平衡性能与安全)
/// - 写入速度: ~50,000 ops/s
/// - 数据安全: 断电丢失 <5秒 或 <16MB 数据
/// - 适用于: 通用应用、API 后端、缓存层
pub fn setupHybridDatabase() !zmdbx.Env {
    var env = try zmdbx.Env.init();

    try env.setGeometry(.{
        .lower = 50 * 1024 * 1024,
        .now = 500 * 1024 * 1024,
        .upper = 50 * 1024 * 1024 * 1024,
        .growth_step = 128 * 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    // 平衡性能参数
    try env.setOption(.OptTxnDpLimit, 131072); // 2x 默认 (128K 页)
    try env.setOption(.OptTxnDpInitial, 4096); // 4x 默认 (4K 页)
    try env.setOption(.OptDpReserveLimit, 4096); // 4x 默认 (4K 页)
    try env.setOption(.OptLooseLimit, 96); // 1.5x 默认 (96 页)

    // 5秒或16MB同步一次
    try env.setSyncBytes(16 * 1024 * 1024);
    try env.setSyncPeriod(5 * 65536); // 5 秒

    try env.open("./hybrid.mdbx", .write_map, 0o755);
    try env.setFlags(.safe_no_sync, true);

    return env;
}

/// 场景 4: 极限性能模式 (仅用于测试或临时缓存)
/// - 写入速度: ~500,000 ops/s
/// - 数据安全: 断电数据完全丢失
/// - 适用于: 性能测试、临时缓存、可重建的数据
pub fn setupUltraHighPerformance() !zmdbx.Env {
    var env = try zmdbx.Env.init();

    try env.setGeometry(.{
        .lower = 100 * 1024 * 1024,
        .now = 1024 * 1024 * 1024,
        .upper = 100 * 1024 * 1024 * 1024,
        .growth_step = 512 * 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    // 极限性能参数
    try env.setOption(.OptTxnDpLimit, 524288); // 8x 默认 (512K 页)
    try env.setOption(.OptTxnDpInitial, 32768); // 32x 默认 (32K 页)
    try env.setOption(.OptDpReserveLimit, 16384); // 16x 默认 (16K 页)
    try env.setOption(.OptLooseLimit, 255); // 最大值 (255 页)

    try env.open("./ultra_perf.mdbx", .write_map, 0o755);
    try env.setFlags(.utterly_no_sync, true);

    return env;
}

/// 演示如何在应用中使用
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n╔════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║        MDBX 高性能配置示例                        ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════╝\n\n", .{});

    // 根据您的场景选择合适的配置
    std.debug.print("正在使用高性能日志配置...\n", .{});

    var env = try setupHighPerformanceLog();
    defer env.deinit();

    // 批量写入测试
    const num_records = 100000;
    const start = std.time.milliTimestamp();

    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);

        var i: usize = 0;
        while (i < num_records) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "log:{d:0>10}", .{i});
            defer allocator.free(key);

            const value = try std.fmt.allocPrint(
                allocator,
                "{{\"timestamp\":{d},\"level\":\"INFO\",\"message\":\"Test log entry {d}\"}}",
                .{ std.time.timestamp(), i },
            );
            defer allocator.free(value);

            try txn.put(dbi, key, value, .upsert);
        }

        try txn.commit();
    }

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_records * 1000, @as(usize, @intCast(elapsed)));

    std.debug.print("\n✓ 成功写入 {} 条记录\n", .{num_records});
    std.debug.print("  耗时: {}ms\n", .{elapsed});
    std.debug.print("  吞吐量: {} ops/s\n", .{ops_per_sec});

    // 手动同步 (确保数据落盘)
    std.debug.print("\n正在手动同步到磁盘...\n", .{});
    try env.sync(true, false);
    std.debug.print("✓ 同步完成!\n", .{});

    // 清理
    std.debug.print("\n正在清理测试数据...\n", .{});
    std.fs.cwd().deleteTree("./log.mdbx") catch {};
    std.debug.print("✓ 完成!\n\n", .{});
}
