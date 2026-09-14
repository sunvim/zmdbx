# MDBX 性能基准测试

## 快速开始

```bash
# 一次跑完全部 4 个基准（推荐）
zig build bench-all -Doptimize=ReleaseFast

# 单独运行
zig build bench       -Doptimize=ReleaseFast   # 6 个标准读写场景
zig build bench-sync  -Doptimize=ReleaseFast   # 4 种同步模式
zig build bench-txn   -Doptimize=ReleaseFast   # 事务批量大小 × 同步模式
zig build bench-sync-opt -Doptimize=ReleaseFast # 同上 bench-sync（历史步骤名）
```

**必须带 `-Doptimize=ReleaseFast`。** 不带就是 Debug 构建：分配器会做泄漏检查、
Zig 侧不做优化，数字能低 1~3 个数量级。基准程序检测到非 Release 构建时会自己打印警告。

## 测量方法（为什么数字可以信）

三条约定，全部写在 `tests/util.zig` 里：

### 1. 热路径零堆分配

早期版本每次操作都用 `allocPrint` 生成 key/value，也就是**每个操作 2 次分配 + 2 次释放**。
这样测出来的其实是分配器的速度，不是 MDBX 的速度 —— 同一份代码：

| 分配器 | 顺序写入吞吐 |
|---|---|
| 0.15 的 `GeneralPurposeAllocator`（ReleaseFast） | 85,000 ops/s |
| 0.16 的 `c_allocator`（ReleaseFast，`main(init).gpa` 的默认值） | 3,500,000 ops/s |
| `DebugAllocator`（Debug 模式默认） | 3,300 ops/s |

差距高达 1000 倍。现在所有基准的 key/value 都在调用方的栈缓冲区里格式化，热路径零分配。

### 2. 每项 1 轮热身 + 4 轮测量，取最快一轮

每个用例都要「删库 → 建库 → 灌数据」，第一轮必然跑在冷页缓存上。
实测同一二进制、同一用例，冷热之间能差 **2 倍**（`SAFE_NOSYNC` 冷跑 3.5M、热跑 8.2M ops/s）。
单次测量没有意义，所以统一由 `util.bench()` 跑 5 轮取最快，并输出「波动」（最慢/最快）供判断。

准备开销（建 200MB 的库、灌数据）全部在 `timer.start()` 之前，不计入吞吐。

### 3. 纳秒级单调时钟

`std.Io.Clock.awake`（macOS 上是 `CLOCK_UPTIME_RAW`）的纳秒读数。
早期用 `std.time.milliTimestamp()`，只有 1ms 分辨率 —— 10 万次操作用时 12ms 时，
量化误差高达 8%。

## 基准项

| 基准 | 内容 |
|---|---|
| `bench` | 顺序写入/随机写入（10 万条）、顺序读取（10 万条）、随机读取（5 万次）、混合读写删（5 万次）、批量删除（5 万条） |
| `bench-sync` | 同一份 10 万条写入在 SYNC_DURABLE / SAFE_NOSYNC / NOMETASYNC / UTTERLY_NOSYNC 下的表现 |
| `bench-txn` | 批大小 10 / 100 / 1000 / 100000 条每事务 × 上述同步模式 |

写入类基准统一使用 `write_map` + `safe_no_sync`（README 推荐的生产配置）。

## 参考结果

环境：Apple M3 Max (16 核) / macOS 26.6 / Zig 0.16.0 / `-Doptimize=ReleaseFast`。

### 标准读写场景（`zig build bench`）

| 测试项 | 吞吐量 | ns/op |
|---|---|---|
| 顺序写入 (10万条) | 8,303,120 ops/s | 120 |
| 随机写入 (10万条) | 3,999,587 ops/s | 250 |
| 顺序读取 (10万条) | 9,996,127 ops/s | 100 |
| 随机读取 (5万次) | 5,813,559 ops/s | 172 |
| 混合操作 (读写删 5万次) | 8,847,992 ops/s | 113 |
| 批量删除 (5万条) | 3,703,429 ops/s | 270 |

### 同步模式（`zig build bench-sync`）

| 模式 | 操作数 | 最快耗时 | 吞吐量 | 安全等级 |
|---|---|---|---|---|
| SYNC_DURABLE | 1万条 | 1.46ms | 6,852,446 ops/s | 🟢 100% 安全 |
| SAFE_NOSYNC | 10万条 | 12.06ms | 8,288,466 ops/s | 🟡 断电<30s丢失 |
| NOMETASYNC | 10万条 | 12.70ms | 7,876,444 ops/s | 🟠 元数据延迟 |
| UTTERLY_NOSYNC | 10万条 | 12.13ms | 8,243,853 ops/s | 🔴 断电全丢失 |

### 事务批量大小（`zig build bench-txn`）

（下表为近似值，单个用例的批间波动约 ±15%）

| 批量 | SYNC_DURABLE | SAFE_NOSYNC | 倍数 |
|---|---|---|---|
| 10 条/txn（1000 次提交） | ~150,000 ops/s | ~1,820,000 ops/s | ~12x |
| 100 条/txn（100 次提交） | ~1,040,000 ops/s | ~6,550,000 ops/s | ~6x |
| 1000 条/txn（10 次提交） | ~4,630,000 ops/s | ~8,660,000 ops/s | ~1.9x |
| 10万条/txn（1 次提交） | ~6,170,000 ops/s | ~8,520,000 ops/s | ~1.4x |

结论和 MDBX 的设计预期一致：**批量越小，`SAFE_NOSYNC` 的价值越大**；
在 macOS/APFS 上 fsync 被 SSD 控制器缓存吸收，所以绝对差距远小于 Linux HDD。

## 性能提示

- **`MDBX_WRITEMAP` 对写入影响约 2 倍**：同一个 100 万次写入的单事务，
  开 `write_map` 是 84 ns/op，不开是 165 ns/op。写入密集的场景建议打开。
- **大批量写事务要放开 dirty-page 上限**：`OptTxnDpLimit` / `OptTxnDpInitial`
  （参见 `examples/high_performance_config.zig`）。默认值偏保守，大事务会提前回落磁盘。
- **`setGeometry` 的 `now` 决定初始文件大小**：基准里用 200MB，避免测量期间反复扩表。
- 库本身的封装开销约等于零：同一份逻辑直调 C API，`mdbx_put`/`mdbx_get`
  是 84ns / 90ns，走 Zig 封装是 85ns / 91ns。

## 历史数字说明

`PERFORMANCE.md` 与更早的 README 里那张「顺序写入 ~85,397 ops/s」的表，
是 **0.15.2 + 每次操作 `allocPrint`** 时代的数字 —— 它测的是
`GeneralPurposeAllocator`，不是 MDBX。同样的硬件上，去掉每操作分配后是 8.3M ops/s。
详见 [PERFORMANCE.md](PERFORMANCE.md) 的「0.16 复测」一节。
