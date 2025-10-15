// 性能压力测试
// 测试 MDBX 在各种场景下的性能表现

const std = @import("std");
const zmdbx = @import("zmdbx");

const BenchResult = struct {
    name: []const u8,
    operations: usize,
    elapsed_ms: i64,
    ops_per_sec: usize,
};

fn printResult(result: BenchResult) void {
    std.debug.print("  {s:<30} | {d:>10} ops | {d:>8}ms | {d:>10} ops/s\n", .{
        result.name,
        result.operations,
        result.elapsed_ms,
        result.ops_per_sec,
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           MDBX Zig 绑定性能压力测试                            ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("测试名称                       |    操作数   |   耗时   |   吞吐量\n", .{});
    std.debug.print("──────────────────────────────────────────────────────────────────\n", .{});

    // 1. 顺序写入测试
    try benchSequentialWrites(allocator);

    // 2. 随机写入测试
    try benchRandomWrites(allocator);

    // 3. 顺序读取测试
    try benchSequentialReads(allocator);

    // 4. 随机读取测试
    try benchRandomReads(allocator);

    // 5. 混合读写测试
    try benchMixedOperations(allocator);

    // 6. 批量删除测试
    try benchBulkDeletes(allocator);

    std.debug.print("\n✓ 所有压测完成！\n\n", .{});
}

fn benchSequentialWrites(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_db_seq_write";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,      // 最小 10MB
        .now = 200 * 1024 * 1024,       // 初始 200MB
        .upper = 2 * 1024 * 1024 * 1024, // 最大 2GB
        .growth_step = 50 * 1024 * 1024, // 增长步长 50MB
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    try env.open(test_path, .defaults, 0o755);

    const num_ops = 100000;
    const start = std.time.milliTimestamp();

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .create);

    var i: usize = 0;
    while (i < num_ops) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
        defer allocator.free(key);

        const value = try std.fmt.allocPrint(allocator, "value_{d}_abcdefghijklmnopqrstuvwxyz", .{i});
        defer allocator.free(value);

        try txn.put(dbi, key, value, .upsert);
    }

    try txn.commit();

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_ops * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "顺序写入 (10万条)",
        .operations = num_ops,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
    });
}

fn benchRandomWrites(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_db_rand_write";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,      // 最小 10MB
        .now = 200 * 1024 * 1024,       // 初始 200MB
        .upper = 2 * 1024 * 1024 * 1024, // 最大 2GB
        .growth_step = 50 * 1024 * 1024, // 增长步长 50MB
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    try env.open(test_path, .defaults, 0o755);

    const num_ops = 50000;
    const start = std.time.milliTimestamp();

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = prng.random();

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .create);

    var i: usize = 0;
    while (i < num_ops) : (i += 1) {
        const rand_id = random.intRangeAtMost(usize, 0, 1000000);
        const key = try std.fmt.allocPrint(allocator, "rkey:{d:0>10}", .{rand_id});
        defer allocator.free(key);

        const value = try std.fmt.allocPrint(allocator, "rvalue_{d}", .{rand_id});
        defer allocator.free(value);

        try txn.put(dbi, key, value, .upsert);
    }

    try txn.commit();

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_ops * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "随机写入 (5万条)",
        .operations = num_ops,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
    });
}

fn benchSequentialReads(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_db_seq_read";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,      // 最小 10MB
        .now = 200 * 1024 * 1024,       // 初始 200MB
        .upper = 2 * 1024 * 1024 * 1024, // 最大 2GB
        .growth_step = 50 * 1024 * 1024, // 增长步长 50MB
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    try env.open(test_path, .defaults, 0o755);

    // 先写入数据
    const num_ops = 100000;
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);

        var i: usize = 0;
        while (i < num_ops) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
            defer allocator.free(key);

            const value = try std.fmt.allocPrint(allocator, "value_{d}", .{i});
            defer allocator.free(value);

            try txn.put(dbi, key, value, .upsert);
        }

        try txn.commit();
    }

    // 顺序读取测试
    const start = std.time.milliTimestamp();

    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);

        var i: usize = 0;
        while (i < num_ops) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
            defer allocator.free(key);

            _ = try txn.get(dbi, key);
        }
    }

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_ops * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "顺序读取 (10万条)",
        .operations = num_ops,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
    });
}

fn benchRandomReads(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_db_rand_read";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,      // 最小 10MB
        .now = 200 * 1024 * 1024,       // 初始 200MB
        .upper = 2 * 1024 * 1024 * 1024, // 最大 2GB
        .growth_step = 50 * 1024 * 1024, // 增长步长 50MB
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    try env.open(test_path, .defaults, 0o755);

    // 先写入数据
    const num_records = 100000;
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);

        var i: usize = 0;
        while (i < num_records) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
            defer allocator.free(key);

            const value = try std.fmt.allocPrint(allocator, "value_{d}", .{i});
            defer allocator.free(value);

            try txn.put(dbi, key, value, .upsert);
        }

        try txn.commit();
    }

    // 随机读取测试
    const num_ops = 50000;
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = prng.random();

    const start = std.time.milliTimestamp();

    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);

        var i: usize = 0;
        while (i < num_ops) : (i += 1) {
            const rand_id = random.intRangeAtMost(usize, 0, num_records - 1);
            const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{rand_id});
            defer allocator.free(key);

            _ = try txn.get(dbi, key);
        }
    }

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_ops * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "随机读取 (5万次)",
        .operations = num_ops,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
    });
}

fn benchMixedOperations(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_db_mixed";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,      // 最小 10MB
        .now = 200 * 1024 * 1024,       // 初始 200MB
        .upper = 2 * 1024 * 1024 * 1024, // 最大 2GB
        .growth_step = 50 * 1024 * 1024, // 增长步长 50MB
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    try env.open(test_path, .defaults, 0o755);

    const num_ops = 50000;
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = prng.random();

    const start = std.time.milliTimestamp();

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .create);

    var i: usize = 0;
    while (i < num_ops) : (i += 1) {
        const operation = random.intRangeAtMost(u8, 0, 2);

        if (operation == 0) {
            // 写入
            const key = try std.fmt.allocPrint(allocator, "key:{d}", .{i});
            defer allocator.free(key);

            const value = try std.fmt.allocPrint(allocator, "value_{d}", .{i});
            defer allocator.free(value);

            try txn.put(dbi, key, value, .upsert);
        } else if (operation == 1 and i > 0) {
            // 读取
            const key = try std.fmt.allocPrint(allocator, "key:{d}", .{random.intRangeAtMost(usize, 0, i - 1)});
            defer allocator.free(key);

            _ = txn.get(dbi, key) catch {};
        } else if (operation == 2 and i > 0) {
            // 删除
            const key = try std.fmt.allocPrint(allocator, "key:{d}", .{random.intRangeAtMost(usize, 0, i - 1)});
            defer allocator.free(key);

            txn.del(dbi, key, null) catch {};
        }
    }

    try txn.commit();

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_ops * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "混合操作 (读写删 5万次)",
        .operations = num_ops,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
    });
}

fn benchBulkDeletes(allocator: std.mem.Allocator) !void {
    const test_path = "./bench_db_deletes";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,      // 最小 10MB
        .now = 200 * 1024 * 1024,       // 初始 200MB
        .upper = 2 * 1024 * 1024 * 1024, // 最大 2GB
        .growth_step = 50 * 1024 * 1024, // 增长步长 50MB
        .shrink_threshold = -1,
        .pagesize = -1,
    });

    try env.open(test_path, .defaults, 0o755);

    // 先写入数据
    const num_records = 50000;
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);

        var i: usize = 0;
        while (i < num_records) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
            defer allocator.free(key);

            const value = try std.fmt.allocPrint(allocator, "value_{d}", .{i});
            defer allocator.free(value);

            try txn.put(dbi, key, value, .upsert);
        }

        try txn.commit();
    }

    // 批量删除测试
    const start = std.time.milliTimestamp();

    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);

        var i: usize = 0;
        while (i < num_records) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
            defer allocator.free(key);

            try txn.del(dbi, key, null);
        }

        try txn.commit();
    }

    const elapsed = std.time.milliTimestamp() - start;
    const ops_per_sec = @divTrunc(num_records * 1000, @as(usize, @intCast(elapsed)));

    printResult(.{
        .name = "批量删除 (5万条)",
        .operations = num_records,
        .elapsed_ms = elapsed,
        .ops_per_sec = ops_per_sec,
    });
}
