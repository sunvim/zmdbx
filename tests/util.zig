//! Zig 0.16 迁移辅助 + 基准测试框架（tests 专用）。
//!
//! ## 迁移部分
//!
//! 0.15 -> 0.16 有两处破坏性变更被本仓库的测试大量使用：
//!
//!   1. `std.fs.*` 迁到 `std.Io.*`，且每个 I/O 调用都要显式传入 `std.Io` 实例。
//!      旧:  `std.fs.cwd().deleteTree(path)`
//!      新:  `std.Io.Dir.cwd().deleteTree(io, path)`
//!
//!   2. `std.time.milliTimestamp()` / `std.time.timestamp()` 被移除，改用
//!      `std.Io.Clock`。旧:  `std.time.milliTimestamp()`
//!      新:  `std.Io.Clock.awake.now(io).toMilliseconds()`
//!
//! 这两类调用在测试里都是「一次性同步调用」，不需要并行能力，因此统一用
//! `std.Io.Threaded.global_single_threaded`。注意它的 allocator 是 `.failing`，
//! 所以这里只做不触发分配的操作（目录增删、读时钟）。
//!
//! ## 基准测试框架
//!
//! 见 `bench` / `printBenchHeader` / `printBenchRow`。三条硬性约定：
//!
//!   1. **热路径零堆分配**。基准测的是 MDBX，不是 malloc —— 每次操作
//!      `allocPrint` 两次会让结果被分配器主导（同一份代码在不同构建模式下
//!      能差 70 倍）。key/value 一律用调用方栈上的固定缓冲区格式化。
//!   2. **热身 + 多轮取最快**。每次测量都要删库重建，第一轮必然在冷页缓存上跑。
//!      实测同一二进制同一用例，冷/热之间能差 2 倍，单次测量没有意义。
//!   3. **纳秒级单调时钟**。`util.millis()` 只有 1ms 分辨率，10 万次操作用时
//!      十几毫秒时量化误差高达 7%。
//!
//! 与 `examples/util.zig` 保持同步 —— Zig 的 `@import` 不能跨模块根目录，
//! 所以两份必须各自存在（这一份多几个只被测试用到的辅助函数）。

const std = @import("std");
const builtin = @import("builtin");

/// 供所有目录操作使用的 `Io` 实例。
pub const io: std.Io = std.Io.Threaded.global_single_threaded.io();

/// 当前工作目录。注意：`cwd()` 返回的句柄不需要（也不允许）close。
pub fn cwd() std.Io.Dir {
    return std.Io.Dir.cwd();
}

/// 递归删除目录，忽略「不存在」等错误。
pub fn deleteTree(path: []const u8) void {
    cwd().deleteTree(io, path) catch {};
}

/// 同 `deleteTree`，但失败时打印一行警告。
pub fn deleteTreeOrWarn(path: []const u8) void {
    cwd().deleteTree(io, path) catch |err| {
        std.debug.print("  警告: 删除 {s} 失败: {t}\n", .{ path, err });
    };
}

/// 创建目录，已存在时不报错。
pub fn makeDir(path: []const u8) !void {
    cwd().createDir(io, path, .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

/// 递归创建目录（含父目录），已存在时不报错。
pub fn makePath(path: []const u8) !void {
    cwd().createDirPath(io, path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

/// 单调时钟的毫秒读数，替代 0.15 的 `std.time.milliTimestamp()`。
/// 只适合做差值（测耗时），绝对值没有意义。
pub fn millis() i64 {
    return std.Io.Clock.awake.now(io).toMilliseconds();
}

/// Unix 纪元秒数，替代 0.15 的 `std.time.timestamp()`。
pub fn timestamp() i64 {
    return std.Io.Clock.real.now(io).toSeconds();
}

// ===========================================================================
// 基准测试框架
// ===========================================================================

/// 每个用例的测量轮数（取最快的一轮作为结果）。
pub const bench_runs: usize = 4;

/// 热身轮数（不计入结果）。第一轮总是跑在冷页缓存上，必须丢掉。
pub const bench_warmups: usize = 1;

/// 单调时钟纳秒读数。
pub fn nanoNow() i96 {
    return std.Io.Clock.awake.now(io).nanoseconds;
}

/// 自 `t0` 起经过的纳秒数。
pub fn nsSince(t0: i96) i64 {
    return @intCast(nanoNow() - t0);
}

pub const BenchResult = struct {
    name: []const u8,
    ops: usize,
    best_ns: i64,
    worst_ns: i64,

    /// 最快一轮对应的吞吐量。
    pub fn opsPerSec(self: BenchResult) f64 {
        if (self.best_ns <= 0) return 0;
        return @as(f64, @floatFromInt(self.ops)) * 1e9 / @as(f64, @floatFromInt(self.best_ns));
    }

    /// 最快一轮对应的单次操作耗时（纳秒）。
    pub fn nsPerOp(self: BenchResult) f64 {
        return @as(f64, @floatFromInt(self.best_ns)) / @as(f64, @floatFromInt(self.ops));
    }

    /// 最慢一轮 / 最快一轮，用来判断这组数字稳不稳。
    pub fn spread(self: BenchResult) f64 {
        if (self.best_ns <= 0) return 0;
        return @as(f64, @floatFromInt(self.worst_ns)) / @as(f64, @floatFromInt(self.best_ns));
    }

    /// 以毫秒表示的最快一轮耗时。
    pub fn bestMs(self: BenchResult) f64 {
        return @as(f64, @floatFromInt(self.best_ns)) / 1e6;
    }
};

/// 打印基准测试标题栏与环境信息。
///
/// Debug 构建下性能会低 1~3 个数量级（分配器带泄漏检查、Zig 侧无优化），
/// 所以这里会额外打一条醒目的警告 —— 基准数字只有在 ReleaseFast 下才有意义。
pub fn printBenchHeader(title: []const u8) void {
    std.debug.print("\n╔════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ {s}\n", .{title});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("Zig {s} | {s} | {s}/{s} | 每项 {d} 轮热身 + {d} 轮测量取最快，热路径零堆分配\n\n", .{
        builtin.zig_version_string,
        @tagName(builtin.mode),
        @tagName(builtin.os.tag),
        builtin.cpu.model.name,
        bench_warmups,
        bench_runs,
    });

    if (builtin.mode != .ReleaseFast and builtin.mode != .ReleaseSmall) {
        std.debug.print("⚠️  当前是 {s} 构建，数字会明显偏低。请用:\n", .{@tagName(builtin.mode)});
        std.debug.print("      zig build <step> -Doptimize=ReleaseFast\n\n", .{});
    }
}

/// 表头行（列宽与 `printBenchRow` 对应）。
pub fn printBenchTableHeader() void {
    std.debug.print("  {s:<28} | {s:>9} | {s:>9} | {s:>12} | {s:>9} | {s:>7}\n", .{
        "测试项",
        "操作数",
        "最快耗时",
        "吞吐量",
        "ns/op",
        "波动",
    });
    std.debug.print("  {s:-<28} | {s:-<9} | {s:-<9} | {s:-<12} | {s:-<9} | {s:-<7}\n", .{
        "", "", "", "", "", "",
    });
}

/// 结果行。`note` 可为空字符串。
pub fn printBenchRow(r: BenchResult, note: []const u8) void {
    std.debug.print("  {s:<28} | {d:>9} | {d:>7.2}ms | {d:>9.0} ops/s | {d:>9.2} | {d:>6.2}x", .{
        r.name,
        r.ops,
        r.bestMs(),
        r.opsPerSec(),
        r.nsPerOp(),
        r.spread(),
    });
    if (note.len != 0) std.debug.print(" | {s}", .{note});
    std.debug.print("\n", .{});
}

/// 手动计时器。
///
/// 基准里总是要「准备（删库/建库/灌数据）→ 计时 → 再准备 → 再计时」，
/// 准备开销（尤其是建 200MB 的库）绝不能算进吞吐里，所以计时区段由 body 自己划。
pub const Timer = struct {
    start_ns: i96 = 0,
    /// 负值表示「没调用过 stop()」——`bench()` 会把这个当成用例写错了。
    elapsed_ns: i64 = -1,

    pub fn start(t: *Timer) void {
        t.start_ns = nanoNow();
    }

    pub fn stop(t: *Timer) void {
        t.elapsed_ns = @intCast(nanoNow() - t.start_ns);
    }
};

/// 通用基准执行器：跑 `bench_warmups + bench_runs` 轮，取最快一轮。
///
/// `body` 是 `fn (ctx: anytype, timer: *Timer) anyerror!void`，每轮自己负责
/// 「准备 → timer.start() → 要测的操作 → timer.stop()」。
pub fn bench(ctx: anytype, comptime body: anytype, name: []const u8, ops: usize) !BenchResult {
    var best: i64 = std.math.maxInt(i64);
    var worst: i64 = 0;

    var round: usize = 0;
    var timer = Timer{};
    while (round < bench_warmups + bench_runs) : (round += 1) {
        timer = .{};
        try body(ctx, &timer);
        if (timer.elapsed_ns < 0) return error.BenchmarkNotTimed;
        if (round >= bench_warmups) {
            if (timer.elapsed_ns < best) best = timer.elapsed_ns;
            if (timer.elapsed_ns > worst) worst = timer.elapsed_ns;
        }
    }

    return .{ .name = name, .ops = ops, .best_ns = best, .worst_ns = worst };
}

test "millis 单调不减" {
    const t0 = millis();
    const t1 = millis();
    try std.testing.expect(t1 >= t0);
}

test "timestamp 落在合理区间" {
    // 2020-01-01 之后
    try std.testing.expect(timestamp() > 1_577_836_800);
}

test "makeDir / deleteTree 幂等" {
    const path = "./zig016_util_probe";
    deleteTree(path);
    try makeDir(path);
    try makeDir(path); // 第二次不应报错
    try makePath(path);
    deleteTree(path);
    deleteTree(path); // 重复删除也不应报错
}

test "bench 取最快一轮" {
    const Ctx = struct { counter: usize = 0 };
    var ctx = Ctx{};
    const body = struct {
        fn run(c: *Ctx, timer: *Timer) anyerror!void {
            c.counter += 1;
            timer.start();
            timer.stop();
        }
    }.run;
    const r = try bench(&ctx, body, "noop", 1000);
    try std.testing.expectEqual(bench_warmups + bench_runs, ctx.counter);
    try std.testing.expect(r.worst_ns >= r.best_ns);
}

test "bench 计时区段之外的开销不计入" {
    const Ctx = struct { prepared: usize = 0 };
    var ctx = Ctx{};
    const body = struct {
        fn run(c: *Ctx, timer: *Timer) anyerror!void {
            c.prepared += 1;
            timer.start();
            timer.stop();
        }
    }.run;
    const r = try bench(&ctx, body, "prep", 1);
    try std.testing.expect(r.best_ns < 10 * std.time.ns_per_ms);
}
