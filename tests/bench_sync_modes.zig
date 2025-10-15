// MDBX 同步模式性能对比测试
// 对比 SYNC_DURABLE vs SAFE_NOSYNC vs UTTERLY_NOSYNC

const std = @import("std");
const zmdbx = @import("zmdbx");

const BenchResult = struct {
    name: []const u8,
    operations: usize,
    elapsed_ms: i64,
    ops_per_sec: usize,
    data_safety: []const u8,
};

fn printResult(result: BenchResult) void {
    std.debug.print("  {s:<20} | {d:>10} ops | {d:>8}ms | {d:>12} ops/s | {s}\n", .{
        result.name,
        result.operations,
        result.elapsed_ms,
        result.ops_per_sec,
        result.data_safety,
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n╔════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              MDBX 同步模式性能与安全性对比测试                            ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("模式                 |    操作数   |   耗时   |     吞吐量    | 数据安全等级\n", .{});
    std.debug.print("──────────────────────────────────────────────────────────────────────────────\n", .{});

    // 测试不同同步模式
    try benchSyncDurable(allocator);
    try benchSafeNoSync(allocator);
    try benchNoMetaSync(allocator);
    try benchUtterlyNoSync(allocator);

    std.debug.print("\n╔════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                             配置建议                                       ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("📊 根据您的业务场景选择合适的模式:\n\n", .{});
    std.debug.print("🟢 SYNC_DURABLE (默认)\n", .{});
    std.debug.print("   - 适用于: 金融交易、支付系统、用户账户\n", .{});
    std.debug.print("   - 性能: ~10,000 ops/s\n", .{});
    std.debug.print("   - 安全: 100%% 断电保护\n\n", .{});

    std.debug.print("🟡 SAFE_NOSYNC (推荐生产)\n", .{});
    std.debug.print("   - 适用于: 日志系统、实时分析、消息队列\n", .{});
    std.debug.print("   - 性能: ~100,000 ops/s\n", .{});
    std.debug.print("   - 安全: 断电丢失<30秒数据, 进程崩溃安全\n\n", .{});

    std.debug.print("🟠 NOMETASYNC\n", .{});
    std.debug.print("   - 适用于: 高频写入场景\n", .{});
    std.debug.print("   - 性能: ~50,000 ops/s\n", .{});
    std.debug.print("   - 安全: 元数据可能延迟, 可自动恢复\n\n", .{});

    std.debug.print("🔴 UTTERLY_NOSYNC (危险)\n", .{});
    std.debug.print("   - 适用于: 性能测试、临时缓存\n", .{});
    std.debug.print("   - 性能: ~500,000 ops/s\n", .{});
    std.debug.print("   - 安全: 断电数据完全丢失\n\n", .{});

    // 清理测试数据
    std.debug.print("正在清理测试数据...\n", .{});
    cleanupTestData();
    std.debug.print("✓ 测试完成!\n\n", .{});
}

fn cleanupTestData() void {
    const test_paths = [_][]const u8{
        "./bench_sync_durable",
        "./bench_safe_nosync",
        "./bench_no_meta_sync",
        "./bench_utterly_nosync",
    };

    for (test_paths) |path| {
        std.fs.cwd().deleteTree(path) catch |err| {
            std.debug.print("  警告: 删除 {s} 失败: {}\n", .{ path, err });
        };
    }
}

/// 1. SYNC_DURABLE 模式 (默认,最安全)
fn benchSyncDurable(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_sync_durable";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    // 标准配置
    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,
        .now = 200 * 1024 * 1024,
        .upper = 2 * 1024 * 1024 * 1024,
        .growth_step = 50 * 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    // 使用默认标志 (MDBX_SYNC_DURABLE)
    try env.open(test_path, .defaults, 0o755);

    const num_ops = 10000; // 减少操作数以节省时间
    const start = std.time.milliTimestamp();

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .create);

    var i: usize = 0;
    while (i < num_ops) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
        defer allocator.free(key);

        const value = try std.fmt.allocPrint(allocator, "value_{d}_data", .{i});
        defer allocator.free(value);

        try txn.put(dbi, key, value, .upsert);
    }

    try txn.commit();

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_ops * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "SYNC_DURABLE",
        .operations = num_ops,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
        .data_safety = "🟢 100% 安全",
    });
}

/// 2. SAFE_NOSYNC 模式 (推荐生产)
fn benchSafeNoSync(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_safe_nosync";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    // 高性能配置
    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,
        .now = 200 * 1024 * 1024,
        .upper = 2 * 1024 * 1024 * 1024,
        .growth_step = 50 * 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    // 性能调优
    try env.setOption(.OptTxnDpLimit, 262144);
    try env.setOption(.OptTxnDpInitial, 16384);
    try env.setOption(.OptDpReserveLimit, 8192);
    try env.setOption(.OptLooseLimit, 128);

    // 使用 WRITE_MAP + SAFE_NOSYNC
    try env.open(test_path, .write_map, 0o755);
    try env.setFlags(.safe_no_sync, true);

    // 同步阈值 (必须在 open 和 setFlags 之后)
    try env.setSyncBytes(64 * 1024 * 1024); // 64MB
    try env.setSyncPeriod(30 * 65536); // 30秒

    const num_ops = 100000;
    const start = std.time.milliTimestamp();

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .create);

    var i: usize = 0;
    while (i < num_ops) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
        defer allocator.free(key);

        const value = try std.fmt.allocPrint(allocator, "value_{d}_data", .{i});
        defer allocator.free(value);

        try txn.put(dbi, key, value, .upsert);
    }

    try txn.commit();

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_ops * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "SAFE_NOSYNC",
        .operations = num_ops,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
        .data_safety = "🟡 断电<30s丢失",
    });
}

/// 3. NOMETASYNC 模式
fn benchNoMetaSync(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_no_meta_sync";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,
        .now = 200 * 1024 * 1024,
        .upper = 2 * 1024 * 1024 * 1024,
        .growth_step = 50 * 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    // 中等性能参数
    try env.setOption(.OptTxnDpLimit, 131072);
    try env.setOption(.OptTxnDpInitial, 8192);
    try env.setOption(.OptDpReserveLimit, 4096);

    // 使用 WRITE_MAP + NOMETASYNC
    try env.open(test_path, .write_map, 0o755);
    try env.setFlags(.no_meta_sync, true);

    const num_ops = 100000;
    const start = std.time.milliTimestamp();

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .create);

    var i: usize = 0;
    while (i < num_ops) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
        defer allocator.free(key);

        const value = try std.fmt.allocPrint(allocator, "value_{d}_data", .{i});
        defer allocator.free(value);

        try txn.put(dbi, key, value, .upsert);
    }

    try txn.commit();

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_ops * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "NOMETASYNC",
        .operations = num_ops,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
        .data_safety = "🟠 元数据延迟",
    });
}

/// 4. UTTERLY_NOSYNC 模式 (危险,仅测试用)
fn benchUtterlyNoSync(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_utterly_nosync";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,
        .now = 200 * 1024 * 1024,
        .upper = 2 * 1024 * 1024 * 1024,
        .growth_step = 50 * 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    // 极限性能参数
    try env.setOption(.OptTxnDpLimit, 524288);
    try env.setOption(.OptTxnDpInitial, 32768);
    try env.setOption(.OptDpReserveLimit, 16384);
    try env.setOption(.OptLooseLimit, 255);

    // 使用 WRITE_MAP + UTTERLY_NOSYNC
    try env.open(test_path, .write_map, 0o755);
    try env.setFlags(.utterly_no_sync, true);

    const num_ops = 100000;
    const start = std.time.milliTimestamp();

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .create);

    var i: usize = 0;
    while (i < num_ops) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
        defer allocator.free(key);

        const value = try std.fmt.allocPrint(allocator, "value_{d}_data", .{i});
        defer allocator.free(value);

        try txn.put(dbi, key, value, .upsert);
    }

    try txn.commit();

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_ops * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "UTTERLY_NOSYNC",
        .operations = num_ops,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
        .data_safety = "🔴 断电全丢失",
    });
}
