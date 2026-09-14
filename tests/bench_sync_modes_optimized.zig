// MDBX 同步模式性能对比（`zig build bench-sync-opt`）
//
// 这个文件早期是一份「手工优化版」的拷贝（和 bench_sync_modes.zig 只差数据库路径），
// 用来证明「消除堆分配能带来 100 倍提升」。现在两个文件都走 tests/util.zig 里
// 同一套「零分配 + 热身 + 取最快」的框架，所以这里只是一层转发，保留旧的步骤名。
pub const main = @import("bench_sync_modes.zig").main;
