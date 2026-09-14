// MDBX 不同事务批量大小的性能对比
//
// 对比「小批量高频提交」与「大批量低频提交」在 SYNC_DURABLE / SAFE_NOSYNC 下的差异。
//
// 与原版的两点区别（都是为了数字可信）：
//   1. 热路径零堆分配：key/value 用栈上缓冲区格式化，不再 `allocPrint`。
//      原版每个操作分配两次，测出来的是分配器的速度（0.15 的 GPA 比 0.16 默认的
//      c_allocator 慢约 40 倍），跟 MDBX 无关。
//   2. 每个用例 1 轮热身 + 4 轮测量取最快，避免第一轮的冷页缓存把结果拉低一倍。

const std = @import("std");
const zmdbx = @import("zmdbx");
const util = @import("util.zig");

/// key: "key:0000000000"（14 字节），value: "value_<i>"（约 10 字节）。
inline fn fmtKey(buf: *[32]u8, i: usize) []const u8 {
    return std.fmt.bufPrint(buf, "key:{d:0>10}", .{i}) catch unreachable;
}

inline fn fmtValue(buf: *[32]u8, i: usize) []const u8 {
    return std.fmt.bufPrint(buf, "value_{d}", .{i}) catch unreachable;
}

const Scenario = struct {
    name: []const u8,
    path_durable: [:0]const u8,
    path_nosync: [:0]const u8,
    batch_size: usize,
    total_ops: usize,

    fn commits(self: Scenario) usize {
        return (self.total_ops + self.batch_size - 1) / self.batch_size;
    }
};

const scenarios = [_]Scenario{
    .{
        .name = "小批量 (10条/txn)",
        .path_durable = "./bench_batch_small_durable",
        .path_nosync = "./bench_batch_small_nosync",
        .batch_size = 10,
        .total_ops = 10_000,
    },
    .{
        .name = "中等批量 (100条/txn)",
        .path_durable = "./bench_batch_medium_durable",
        .path_nosync = "./bench_batch_medium_nosync",
        .batch_size = 100,
        .total_ops = 10_000,
    },
    .{
        .name = "大批量 (1000条/txn)",
        .path_durable = "./bench_batch_large_durable",
        .path_nosync = "./bench_batch_large_nosync",
        .batch_size = 1000,
        .total_ops = 10_000,
    },
    .{
        .name = "超大批量 (10万条/txn)",
        .path_durable = "./bench_batch_huge_durable",
        .path_nosync = "./bench_batch_huge_nosync",
        .batch_size = 100_000,
        .total_ops = 100_000,
    },
};

/// 一次测量：批大小 + 同步模式。准备阶段（删库/建库）不计时。
const Job = struct {
    sc: Scenario,
    safe_nosync: bool,
};

fn runJob(job: Job, timer: *util.Timer) anyerror!void {
    const path = if (job.safe_nosync) job.sc.path_nosync else job.sc.path_durable;
    util.deleteTree(path);

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

    var open_flags = zmdbx.EnvFlagSet.init(.{});
    if (job.safe_nosync) {
        open_flags.insert(.write_map);
        try env.setOption(.OptTxnDpLimit, 1 << 20);
        try env.setOption(.OptTxnDpInitial, 1 << 16);
    }
    try env.open(path, open_flags, 0o755);

    if (job.safe_nosync) {
        var sync_flags = zmdbx.EnvFlagSet.init(.{});
        sync_flags.insert(.safe_no_sync);
        try env.setFlags(sync_flags, true);
        try env.setSyncBytes(64 * 1024 * 1024);
        try env.setSyncPeriod(30 * 65536);
    }

    var kb: [32]u8 = undefined;
    var vb: [32]u8 = undefined;

    timer.start();
    var i: usize = 0;
    while (i < job.sc.total_ops) {
        var txn = try env.beginWriteTxn();
        errdefer txn.abort();

        const db_flags = zmdbx.DBFlagSet.init(.{ .create = true });
        const dbi = try txn.openDBI(null, db_flags);

        var batch: usize = 0;
        while (batch < job.sc.batch_size and i < job.sc.total_ops) : ({
            batch += 1;
            i += 1;
        }) {
            try txn.put(dbi, fmtKey(&kb, i), fmtValue(&vb, i), zmdbx.PutFlagSet.init(.{}));
        }

        try txn.commit();
    }
    timer.stop();
}

fn printRow(label: []const u8, mode: []const u8, r: util.BenchResult, commits: usize) void {
    const ms = r.bestMs();
    const txn_per_sec = if (ms > 0) @as(f64, @floatFromInt(commits)) * 1000.0 / ms else 0;
    std.debug.print("  {s:<18} | {s:<13} | {d:>7} ops | {d:>5} txn | {d:>7.2}ms | {d:>10.0} ops/s | {d:>9.0} txn/s\n", .{
        label,
        mode,
        r.ops,
        commits,
        ms,
        r.opsPerSec(),
        txn_per_sec,
    });
}

pub fn main() !void {
    util.printBenchHeader("MDBX 事务批量大小 × 同步模式");
    std.debug.print("  {s:<18} | {s:<13} | {s:>11} | {s:>9} | {s:>9} | {s:>16} | {s:>14}\n", .{
        "批量",
        "同步模式",
        "操作数",
        "提交数",
        "最快耗时",
        "吞吐量",
        "提交速率",
    });
    std.debug.print("  {s:-<18}-|-{s:-<13}-|-{s:-<11}-|-{s:-<9}-|-{s:-<9}-|-{s:-<16}-|-{s:-<14}\n", .{
        "", "", "", "", "", "", "",
    });

    for (scenarios) |sc| {
        for ([_]bool{ true, false }) |safe_nosync| {
            const job = Job{ .sc = sc, .safe_nosync = safe_nosync };
            const mode_name = if (safe_nosync) "SAFE_NOSYNC" else "SYNC_DURABLE";
            const result = try util.bench(job, runJob, mode_name, sc.total_ops);
            printRow(sc.name, mode_name, result, sc.commits());
        }
    }

    std.debug.print("\n读数说明:\n", .{});
    std.debug.print("  - 每行 = 1 轮热身 + 4 轮测量取最快；准备（删库/建库）不计时。\n", .{});
    std.debug.print("  - SAFE_NOSYNC 行额外开了 write_map 并放开 dirty-page 上限，这是 README 推荐的生产配置。\n", .{});
    std.debug.print("  - macOS/APFS 上 fsync 被 SSD 控制器缓存吸收，两种模式的差距远小于 Linux HDD 上的表现。\n", .{});

    cleanupTestData();
}

fn cleanupTestData() void {
    const test_paths = [_][]const u8{
        "./bench_batch_small_durable",  "./bench_batch_small_nosync",
        "./bench_batch_medium_durable", "./bench_batch_medium_nosync",
        "./bench_batch_large_durable",  "./bench_batch_large_nosync",
        "./bench_batch_huge_durable",   "./bench_batch_huge_nosync",
    };

    for (test_paths) |path| {
        util.deleteTree(path);
    }
}
