//! Zig 0.16 迁移辅助（examples 专用）。
//!
//! 与 `tests/util.zig` 保持同步 —— Zig 的 `@import` 不能跨越模块根目录，
//! 所以两份必须各自存在（`tests/` 那份多几个只被测试用到的辅助函数）。
//!
//! 0.15 -> 0.16 有两处破坏性变更被本目录的示例大量使用：
//!
//!   1. `std.fs.*` 迁到 `std.Io.*`，且每个 I/O 调用都要显式传入 `std.Io` 实例。
//!      旧:  `std.fs.cwd().deleteTree(path)`
//!      新:  `std.Io.Dir.cwd().deleteTree(io, path)`
//!
//!   2. `std.time.milliTimestamp()` / `std.time.timestamp()` 被移除，改用
//!      `std.Io.Clock`。旧:  `std.time.milliTimestamp()`
//!      新:  `std.Io.Clock.awake.now(io).toMilliseconds()`

const std = @import("std");

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

/// 创建目录，已存在时不报错。
pub fn makeDir(path: []const u8) !void {
    cwd().createDir(io, path, .default_dir) catch |err| switch (err) {
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
