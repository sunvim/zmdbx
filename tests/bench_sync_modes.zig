// MDBX 同步模式性能对比
//
// 四个模式（SYNC_DURABLE / SAFE_NOSYNC / NOMETASYNC / UTTERLY_NOSYNC）在同一台机器上
// 跑同一份 10 万条写入，看「数据安全等级」值多少性能。
//
// 热路径零堆分配（key/value 用栈上缓冲区），每项 1 轮热身 + 4 轮测量取最快。
// 详见 tests/util.zig 顶部的「基准测试框架」说明。

const std = @import("std");
const zmdbx = @import("zmdbx");
const util = @import("util.zig");

/// 一个同步模式的全部配置。
const Case = struct {
    name: []const u8,
    path: [:0]const u8,
    ops: usize,
    /// open 时传入的标志
    open_flags: zmdbx.EnvFlagSet,
    /// open 之后 setFlags 打开的标志
    set_flags: zmdbx.EnvFlagSet,
    /// 是否放开 dirty-page 上限（大批量写事务必备）
    tune_dp: bool = false,
    dp_limit: u64 = 0,
    dp_initial: u64 = 0,
    dp_reserve: u64 = 0,
    loose_limit: u64 = 0,
    sync_bytes: usize = 0,
    sync_period: c_uint = 0,
    safety: []const u8,
};

fn envFlags(comptime base: zmdbx.EnvFlagSet, comptime extra: zmdbx.EnvFlag) zmdbx.EnvFlagSet {
    var f = base;
    f.insert(extra);
    return f;
}

const cases = [_]Case{
    .{
        .name = "SYNC_DURABLE",
        .path = "./bench_sync_durable",
        .ops = 10_000,
        .open_flags = zmdbx.EnvFlagSet.init(.{}),
        .set_flags = zmdbx.EnvFlagSet.init(.{}),
        .safety = "🟢 100% 安全",
    },
    .{
        .name = "SAFE_NOSYNC",
        .path = "./bench_safe_nosync",
        .ops = 100_000,
        .open_flags = envFlags(zmdbx.EnvFlagSet.init(.{}), .write_map),
        .set_flags = envFlags(zmdbx.EnvFlagSet.init(.{}), .safe_no_sync),
        .tune_dp = true,
        .dp_limit = 262_144,
        .dp_initial = 16_384,
        .dp_reserve = 8192,
        .loose_limit = 128,
        .sync_bytes = 64 * 1024 * 1024,
        .sync_period = 30 * 65536,
        .safety = "🟡 断电<30s丢失",
    },
    .{
        .name = "NOMETASYNC",
        .path = "./bench_no_meta_sync",
        .ops = 100_000,
        .open_flags = envFlags(zmdbx.EnvFlagSet.init(.{}), .write_map),
        .set_flags = envFlags(zmdbx.EnvFlagSet.init(.{}), .no_meta_sync),
        .tune_dp = true,
        .dp_limit = 131_072,
        .dp_initial = 8192,
        .dp_reserve = 4096,
        .safety = "🟠 元数据延迟",
    },
    .{
        .name = "UTTERLY_NOSYNC",
        .path = "./bench_utterly_nosync",
        .ops = 100_000,
        .open_flags = envFlags(zmdbx.EnvFlagSet.init(.{}), .write_map),
        .set_flags = envFlags(zmdbx.EnvFlagSet.init(.{}), .utterly_no_sync),
        .tune_dp = true,
        .dp_limit = 524_288,
        .dp_initial = 32_768,
        .dp_reserve = 16_384,
        .loose_limit = 255,
        .safety = "🔴 断电全丢失",
    },
};

/// key: "key:0000000000"（14 字节），value: "value_<i>_data"（约 18 字节）。
inline fn fmtKey(buf: *[32]u8, i: usize) []const u8 {
    return std.fmt.bufPrint(buf, "key:{d:0>10}", .{i}) catch unreachable;
}

inline fn fmtValue(buf: *[32]u8, i: usize) []const u8 {
    return std.fmt.bufPrint(buf, "value_{d}_data", .{i}) catch unreachable;
}

fn runCase(c: Case, timer: *util.Timer) anyerror!void {
    util.deleteTree(c.path);

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

    if (c.tune_dp) {
        try env.setOption(.OptTxnDpLimit, c.dp_limit);
        try env.setOption(.OptTxnDpInitial, c.dp_initial);
        try env.setOption(.OptDpReserveLimit, c.dp_reserve);
        if (c.loose_limit != 0) try env.setOption(.OptLooseLimit, c.loose_limit);
    }

    try env.open(c.path, c.open_flags, 0o755);

    if (c.set_flags.count() != 0) {
        try env.setFlags(c.set_flags, true);
    }
    if (c.sync_bytes != 0) try env.setSyncBytes(c.sync_bytes);
    if (c.sync_period != 0) try env.setSyncPeriod(c.sync_period);

    var txn = try env.beginWriteTxn();
    defer txn.abort();

    const db_flags = zmdbx.DBFlagSet.init(.{ .create = true });
    const dbi = try txn.openDBI(null, db_flags);

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

pub fn main() !void {
    util.printBenchHeader("MDBX 同步模式性能与安全性对比");
    util.printBenchTableHeader();

    for (cases) |c| {
        const r = try util.bench(c, runCase, c.name, c.ops);
        util.printBenchRow(r, c.safety);
    }

    std.debug.print("\n配置建议:\n", .{});
    std.debug.print("  🟢 SYNC_DURABLE   — 金融交易、支付、账户: 断电 100% 安全\n", .{});
    std.debug.print("  🟡 SAFE_NOSYNC    — 日志、实时分析、消息队列: 进程崩溃安全，断电丢 <30s 数据\n", .{});
    std.debug.print("  🟠 NOMETASYNC     — 高频写入: 元数据可能延迟，可自动恢复\n", .{});
    std.debug.print("  🔴 UTTERLY_NOSYNC — 仅压测/临时缓存: 断电数据全丢\n", .{});
    std.debug.print("\n注意: macOS/APFS 上 fsync 会被 SSD 控制器缓存吸收，四个模式差距很小；\n", .{});
    std.debug.print("      部署到 Linux/HDD 时 SAFE_NOSYNC 与 SYNC_DURABLE 的差距可达 100 倍以上。\n", .{});

    cleanupTestData();
}

fn cleanupTestData() void {
    for (cases) |c| {
        util.deleteTreeOrWarn(c.path);
    }
}
