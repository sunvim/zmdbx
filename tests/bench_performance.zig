// 性能压力测试（6 个标准场景）
//
// ## 为什么这个文件里没有一个 `allocPrint`
//
// 原版每次操作都 `allocPrint` 出 key 和 value，于是基准实际测的是分配器而不是
// MDBX：同一份逻辑在 Debug / ReleaseFast 之间差 70 倍，在 0.15 的 GPA 与 0.16 的
// c_allocator 之间差 40 倍。现在 key/value 全部在调用方的栈缓冲区里格式化
// （`fmtKey` / `fmtValue`），热路径零堆分配。
//
// ## 计时方式
//
// 每次测量都要「删库 → 建库 → 灌数据」，第一轮必然跑在冷页缓存上。因此统一由
// `util.bench()` 跑 1 轮热身 + 4 轮测量取最快，且准备开销（建 200MB 库、灌数据）
// 全在 `timer.start()` 之前，不计入吞吐。

const std = @import("std");
const zmdbx = @import("zmdbx");
const util = @import("util.zig");

const SEQ_WRITE_OPS = 100_000;
const RAND_WRITE_OPS = 100_000;
const SEQ_READ_OPS = 100_000;
const RAND_READ_OPS = 50_000;
const MIXED_OPS = 50_000;
const BULK_DELETE_OPS = 50_000;

/// key: "key:0000000000"（14 字节），value: "value_<i>_data"（约 18 字节）。
inline fn fmtKey(buf: *[32]u8, i: usize) []const u8 {
    return std.fmt.bufPrint(buf, "key:{d:0>10}", .{i}) catch unreachable;
}

inline fn fmtValue(buf: *[32]u8, i: usize) []const u8 {
    return std.fmt.bufPrint(buf, "value_{d}_data", .{i}) catch unreachable;
}

/// 用例配置。`write_map` + `safe_no_sync` 与 README 推荐的生产配置一致。
const Cfg = struct {
    path: [:0]const u8,
    ops: usize,
    prep_ops: usize = 0,
};

/// 删库 + 建库 + 打开（打开开销大，放在计时区段之外）。
fn openFreshEnv(cfg: Cfg) !zmdbx.Env {
    util.deleteTree(cfg.path);

    var env = try zmdbx.Env.init();
    errdefer env.deinit();

    try env.setGeometry(.{
        .lower = 10 * 1024 * 1024,
        .now = 200 * 1024 * 1024,
        .upper = 2 * 1024 * 1024 * 1024,
        .growth_step = 50 * 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    });
    try env.setOption(.OptTxnDpLimit, 1 << 20);
    try env.setOption(.OptTxnDpInitial, 1 << 16);

    var flags = zmdbx.EnvFlagSet.init(.{});
    flags.insert(.write_map);
    try env.open(cfg.path, flags, 0o755);

    var sync_flags = zmdbx.EnvFlagSet.init(.{});
    sync_flags.insert(.safe_no_sync);
    try env.setFlags(sync_flags, true);

    return env;
}

fn openDBI(txn: *zmdbx.Txn) !zmdbx.DBI {
    const db_flags = zmdbx.DBFlagSet.init(.{ .create = true });
    return txn.openDBI(null, db_flags);
}

/// 灌 `count` 条数据（用于读场景的准备阶段）。
fn populate(env: *zmdbx.Env, count: usize) !void {
    var txn = try env.beginWriteTxn();
    defer txn.abort();
    const dbi = try openDBI(&txn);

    var kb: [32]u8 = undefined;
    var vb: [32]u8 = undefined;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        try txn.put(dbi, fmtKey(&kb, i), fmtValue(&vb, i), zmdbx.PutFlagSet.init(.{}));
    }
    try txn.commit();
}

pub fn main() !void {
    util.printBenchHeader("MDBX Zig 绑定性能压力测试");
    util.printBenchTableHeader();

    try benchSequentialWrites();
    try benchRandomWrites();
    try benchSequentialReads();
    try benchRandomReads();
    try benchMixedOperations();
    try benchBulkDeletes();

    std.debug.print("\n提示: MDBX 的写入吞吐与 MDBX_WRITEMAP 强相关，不带 WRITEMAP 时约慢 2 倍。\n", .{});
    std.debug.print("      上面所有用例都使用 write_map + safe_no_sync（README 推荐的生产配置）。\n", .{});

    cleanupTestData();
}

fn cleanupTestData() void {
    const test_paths = [_][]const u8{
        "./bench_db_seq_write",
        "./bench_db_rand_write",
        "./bench_db_seq_read",
        "./bench_db_rand_read",
        "./bench_db_mixed",
        "./bench_db_bulk_delete",
    };

    for (test_paths) |path| {
        util.deleteTreeOrWarn(path);
    }
}

/// 顺序写入：100k 条，单事务。
fn benchSequentialWrites() !void {
    const cfg = Cfg{ .path = "./bench_db_seq_write", .ops = SEQ_WRITE_OPS };

    const body = struct {
        fn run(c: Cfg, timer: *util.Timer) anyerror!void {
            var env = try openFreshEnv(c);
            defer env.deinit();

            var txn = try env.beginWriteTxn();
            defer txn.abort();
            const dbi = try openDBI(&txn);

            var kb: [32]u8 = undefined;
            var vb: [32]u8 = undefined;

            timer.start();
            var i: usize = 0;
            while (i < c.ops) : (i += 1) {
                try txn.put(dbi, fmtKey(&kb, i), fmtValue(&vb, i), zmdbx.PutFlagSet.init(.{}));
            }
            try txn.commit();
            timer.stop();
        }
    }.run;

    util.printBenchRow(try util.bench(cfg, body, "顺序写入 (10万条)", cfg.ops), "");
}

/// 随机写入：100k 条，单事务，key 空间 100 万以避免总是命中同一页。
fn benchRandomWrites() !void {
    const cfg = Cfg{ .path = "./bench_db_rand_write", .ops = RAND_WRITE_OPS };

    const body = struct {
        fn run(c: Cfg, timer: *util.Timer) anyerror!void {
            var env = try openFreshEnv(c);
            defer env.deinit();

            var prng = std.Random.DefaultPrng.init(@intCast(util.timestamp()));
            const random = prng.random();

            var txn = try env.beginWriteTxn();
            defer txn.abort();
            const dbi = try openDBI(&txn);

            var kb: [32]u8 = undefined;
            var vb: [32]u8 = undefined;

            timer.start();
            var i: usize = 0;
            while (i < c.ops) : (i += 1) {
                const id = random.intRangeLessThan(usize, 0, c.ops * 10);
                try txn.put(dbi, fmtKey(&kb, id), fmtValue(&vb, id), zmdbx.PutFlagSet.init(.{}));
            }
            try txn.commit();
            timer.stop();
        }
    }.run;

    util.printBenchRow(try util.bench(cfg, body, "随机写入 (10万条)", cfg.ops), "");
}

/// 顺序读取：先灌 100k 条，再用只读事务顺序读回来。
fn benchSequentialReads() !void {
    const cfg = Cfg{ .path = "./bench_db_seq_read", .ops = SEQ_READ_OPS, .prep_ops = SEQ_READ_OPS };

    const body = struct {
        fn run(c: Cfg, timer: *util.Timer) anyerror!void {
            var env = try openFreshEnv(c);
            defer env.deinit();
            try populate(&env, c.prep_ops);

            const db_flags = zmdbx.DBFlagSet.init(.{});
            var txn = try env.beginReadTxn();
            defer txn.abort();
            const dbi = try txn.openDBI(null, db_flags);

            var kb: [32]u8 = undefined;
            var sum: usize = 0;

            timer.start();
            var i: usize = 0;
            while (i < c.ops) : (i += 1) {
                const v = try txn.getBytes(dbi, fmtKey(&kb, i));
                sum +%= v.len;
            }
            timer.stop();
            std.mem.doNotOptimizeAway(sum);
        }
    }.run;

    util.printBenchRow(try util.bench(cfg, body, "顺序读取 (10万条)", cfg.ops), "");
}

/// 随机读取：先灌 100k 条，再随机读 50k 次。
fn benchRandomReads() !void {
    const cfg = Cfg{ .path = "./bench_db_rand_read", .ops = RAND_READ_OPS, .prep_ops = 100_000 };

    const body = struct {
        fn run(c: Cfg, timer: *util.Timer) anyerror!void {
            var env = try openFreshEnv(c);
            defer env.deinit();
            try populate(&env, c.prep_ops);

            var prng = std.Random.DefaultPrng.init(@intCast(util.timestamp()));
            const random = prng.random();

            const db_flags = zmdbx.DBFlagSet.init(.{});
            var txn = try env.beginReadTxn();
            defer txn.abort();
            const dbi = try txn.openDBI(null, db_flags);

            var kb: [32]u8 = undefined;
            var sum: usize = 0;

            timer.start();
            var i: usize = 0;
            while (i < c.ops) : (i += 1) {
                const id = random.intRangeLessThan(usize, 0, c.prep_ops);
                const v = try txn.getBytes(dbi, fmtKey(&kb, id));
                sum +%= v.len;
            }
            timer.stop();
            std.mem.doNotOptimizeAway(sum);
        }
    }.run;

    util.printBenchRow(try util.bench(cfg, body, "随机读取 (5万次)", cfg.ops), "");
}

/// 混合操作：写 1 条 + 读 1 条 + 删 1 条，共 50k 轮。
fn benchMixedOperations() !void {
    const cfg = Cfg{ .path = "./bench_db_mixed", .ops = MIXED_OPS };

    const body = struct {
        fn run(c: Cfg, timer: *util.Timer) anyerror!void {
            var env = try openFreshEnv(c);
            defer env.deinit();

            var txn = try env.beginWriteTxn();
            defer txn.abort();
            const dbi = try openDBI(&txn);

            var kb: [32]u8 = undefined;
            var vb: [32]u8 = undefined;

            timer.start();
            var i: usize = 0;
            while (i < c.ops) : (i += 1) {
                const key = fmtKey(&kb, i);
                try txn.put(dbi, key, fmtValue(&vb, i), zmdbx.PutFlagSet.init(.{}));
                _ = try txn.getBytes(dbi, key);
                try txn.del(dbi, key, null);
            }
            try txn.commit();
            timer.stop();
        }
    }.run;

    util.printBenchRow(try util.bench(cfg, body, "混合操作 (读写删 5万次)", cfg.ops), "");
}

/// 批量删除：先写 50k 条（不计时），再在一个写事务里全部删掉。
fn benchBulkDeletes() !void {
    const cfg = Cfg{ .path = "./bench_db_bulk_delete", .ops = BULK_DELETE_OPS };

    const body = struct {
        fn run(c: Cfg, timer: *util.Timer) anyerror!void {
            var env = try openFreshEnv(c);
            defer env.deinit();
            try populate(&env, c.ops);

            var txn = try env.beginWriteTxn();
            defer txn.abort();
            const db_flags = zmdbx.DBFlagSet.init(.{});
            const dbi = try txn.openDBI(null, db_flags);

            var kb: [32]u8 = undefined;

            timer.start();
            var i: usize = 0;
            while (i < c.ops) : (i += 1) {
                try txn.del(dbi, fmtKey(&kb, i), null);
            }
            try txn.commit();
            timer.stop();
        }
    }.run;

    util.printBenchRow(try util.bench(cfg, body, "批量删除 (5万条)", cfg.ops), "");
}
