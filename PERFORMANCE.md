# zmdbx 性能优化报告

## 0.16 复测（2026）—— 结论先行

从 0.15.2 升到 0.16.0 之后，基准数字与 README 里记的对不上，实测排查结论是：

> **MDBX 本身没有任何回退。真正的差异全部来自「基准测的是分配器，不是 MDBX」**
> 以及 Debug/ReleaseFast、冷/热页缓存这三件事。

### 证据

**1) 两边链接同一个 `mdbx.o`（同一份 C 代码、同一套 flags），只用不同 Zig 编译器编译同一份基准源码：**

| 基准 | 0.15.2 | 0.16.0 |
|---|---|---|
| `bench_sync_modes`（零分配） | 2.5M / 4.0M / 5.0M / 6.7M ops/s | 2.5M / 4.3M / 5.5M / 6.7M ops/s |

逐项吻合到噪声以内 —— 编译器换代对 MDBX 吞吐没有影响。

**2) 绑定的封装开销也约等于零**（100 万次 put + 100 万次 get，二进制 key，单事务）：

| 实现 | PUT | GET |
|---|---|---|
| 纯 C（`mdbx_put` / `mdbx_get`） | 84 ns/op | 90 ns/op |
| Zig 封装（`Txn.put` / `Txn.getBytes`） | 85 ns/op | 91 ns/op |

**3) 差异真正的来源 —— 同一份 `bench_performance` 换个分配器就变 40~1000 倍：**

| 组合 | 顺序写入吞吐 |
|---|---|
| 0.15.2 ReleaseFast，每次操作 `allocPrint` + `GeneralPurposeAllocator` | 85,000 ops/s |
| 0.16.0 ReleaseFast，每次操作 `allocPrint` + `main(init).gpa` = `c_allocator` | 3,500,000 ops/s |
| 0.16.0 Debug，每次操作 `allocPrint` + `DebugAllocator` | 3,350 ops/s |
| 0.15.2 Debug，同上 | 17,300 ops/s |
| 两边任一版本，栈上缓冲区零分配 | 8,300,000 ops/s |

**4) 单次测量的不可复现性：** 同一个二进制、同一个用例，第一轮（冷页缓存、
新建 200MB 库）能比后续轮次慢 **2 倍** —— `SAFE_NOSYNC` 冷跑 3.5M、热跑 8.2M ops/s。

### 结论

| 现象 | 真实原因 | 处置 |
|---|---|---|
| ReleaseFast 下「性能差很多」 | 旧数字含每操作分配，新数字不含（或反之） | 基准改为零分配 |
| 0.16 比 0.15 慢（Debug） | 0.16 的 `main(init)` 在 Debug 下默认给 `DebugAllocator`（带泄漏检查）；0.15 的基准用自己的 `GeneralPurposeAllocator`，两者开销不同 | 基准不再分配，Debug/Release 数字也收敛 |
| 同一命令两次跑出 2 倍差异 | 冷/热页缓存 + 单次测量 | 1 轮热身 + 4 轮取最快 |
| 与 README 表格对不上 | 那张表是 0.15.2 + `allocPrint` 时代的数字 | README / BENCHMARKS.md 已按新方法重写 |

### 顺带发现的真优化

- **`MDBX_WRITEMAP` 对写入约 2 倍**：100 万次单事务写入，开启 84 ns/op、不开启 165 ns/op。
- **基准/示例可执行文件重复链接 mdbx 静态库**：`build.zig` 里既 `addImport` 了 lib 的
  module（module 自带 mdbx.c + include path + libc）、又 `linkLibrary(lib)`，
  于是每个可执行文件都多链一遍 mdbx（静态库那份是死代码）。已去掉多余的
  `linkLibrary`，冷构建从 13.8s 降到 11.5s。
- **`bench_sync_modes_optimized.zig` 是 `bench_sync_modes.zig` 的纯拷贝**，已折叠为转发。

---

## 以下为历史记录（0.15.2 时代的优化过程）

> ⚠️ 下面的表格保留了当时的原始数字。其中「原始性能」与「优化后性能」的差异，
> 主要是**消除每操作堆分配**带来的：它确实让基准快了 100 倍，但那 100 倍
> 属于分配器，而不是 MDBX 的写入能力。绝对数值请以
> [BENCHMARKS.md](BENCHMARKS.md) 的最新复测为准。

## 概述

本报告记录了 zmdbx (Zig MDBX 绑定) 的性能优化过程及结果。通过系统性的分析和优化，我们将性能提升了 **100倍**，最终超过了 Golang gmdbx 的性能。

## 优化前后对比

### 原始性能 (优化前)
```
模式                 |    操作数   |   耗时   |     吞吐量
──────────────────────────────────────────────────────────
SYNC_DURABLE         |  10,000 ops |    171ms |    58,479 ops/s
SAFE_NOSYNC          | 100,000 ops |  1,604ms |    62,344 ops/s
NOMETASYNC           | 100,000 ops |  1,594ms |    62,735 ops/s
UTTERLY_NOSYNC       | 100,000 ops |  1,568ms |    63,775 ops/s
```

### 优化后性能
```
模式                 |    操作数   |   耗时   |     吞吐量
──────────────────────────────────────────────────────────
SYNC_DURABLE         |  10,000 ops |      3ms | 3,333,333 ops/s  ⬆️ 58x
SAFE_NOSYNC          | 100,000 ops |     19ms | 5,263,157 ops/s  ⬆️ 84x
NOMETASYNC           | 100,000 ops |     17ms | 5,882,352 ops/s  ⬆️ 94x
UTTERLY_NOSYNC       | 100,000 ops |     14ms | 7,142,857 ops/s  ⬆️ 112x
```

### 与 Golang gmdbx 对比
```
模式                 | zmdbx (Zig)      | gmdbx (Go)       | 提升
────────────────────────────────────────────────────────────────────
SYNC_DURABLE         | 3,333,333 ops/s  | 1,666,666 ops/s  | 2.0x 🚀
SAFE_NOSYNC          | 5,263,157 ops/s  | 2,500,000 ops/s  | 2.1x 🚀
NOMETASYNC           | 5,882,352 ops/s  | 3,333,333 ops/s  | 1.8x 🚀
UTTERLY_NOSYNC       | 7,142,857 ops/s  | 3,703,703 ops/s  | 1.9x 🚀
```

## 关键优化措施

### 1. 消除堆内存分配 (影响最大 ~80%)

**问题**: 每次操作使用 `allocPrint` 进行动态内存分配
```zig
// 优化前 - 100,000次操作 = 200,000次堆分配
const key = try std.fmt.allocPrint(allocator, "key:{d:0>10}", .{i});
defer allocator.free(key);
const value = try std.fmt.allocPrint(allocator, "value_{d}_data", .{i});
defer allocator.free(value);
```

**解决方案**: 使用栈上固定缓冲区
```zig
// 优化后 - 零堆分配
var key_buf: [32]u8 = undefined;
var value_buf: [64]u8 = undefined;

inline fn formatKey(buf: []u8, i: usize) []const u8 {
    return std.fmt.bufPrint(buf, "key:{d:0>10}", .{i}) catch unreachable;
}
```

**原因**:
- 内存分配器开销(锁竞争、元数据管理、碎片整理)
- CPU缓存失效(堆分配地址随机，栈分配连续)
- 函数调用开销(allocate/free函数调用)

### 2. C代码编译优化 (影响 ~15%)

添加激进的编译器优化选项:
```zig
"-O3",                    // 最高级别优化
"-march=native",          // 针对本地CPU优化
"-mtune=native",          // 针对本地CPU调优
"-fomit-frame-pointer",   // 省略栈帧指针
"-funroll-loops",         // 循环展开
"-finline-functions",     // 内联函数
```

**原因**:
- `-O3`: 启用所有优化(包括向量化、自动并行化)
- `-march=native`: 使用AVX2/SSE等SIMD指令
- `-funroll-loops`: 减少分支预测失败

### 3. 保持其他优化配置 (影响 ~5%)

继续使用已有的MDBX性能调优:
- `WRITE_MAP`: 使用内存映射写入
- `SAFE_NOSYNC`: 平衡性能与安全
- 调优的事务参数(TxnDpLimit, TxnDpInitial等)
- 适当的同步阈值(SyncBytes, SyncPeriod)

## 性能分析方法

1. **识别瓶颈**: 使用时间测量定位热点代码
2. **Profile分析**: 确认内存分配是主要瓶颈
3. **逐步优化**: 先解决最大瓶颈，再优化次要问题
4. **基准对比**: 每次优化后运行基准测试验证效果

## 内存模型对比

### Zig栈分配优势
```
栈分配: [key_buf][value_buf]  ← 连续内存，L1缓存命中
          ↑
      线性地址空间，CPU预取友好
```

### 堆分配劣势
```
堆分配: 0x1234 → [key]
        0x5678 → [value]  ← 随机分布，缓存失效
                          ← 需要malloc/free开销
```

## 编译器优化效果

使用 `-O3 -march=native` 后的效果:
- **向量化**: SIMD指令并行处理多个操作
- **循环展开**: 减少分支预测和循环控制开销
- **内联**: 消除函数调用开销
- **常量传播**: 编译期计算

## 结论

通过系统性的性能优化，zmdbx 达到了以下成果:

1. ✅ **性能提升100倍**: 从 ~60K ops/s 提升到 ~6M ops/s
2. ✅ **超越Golang**: 比 gmdbx 快 1.8-2.1倍
3. ✅ **零运行时分配**: 使用栈内存，无GC压力
4. ✅ **接近C性能**: 充分利用Zig的零成本抽象

### 为什么比Golang快?

1. **无GC开销**: Zig使用栈分配，Go有GC暂停
2. **更好的内联**: Zig的 `inline` 强制内联
3. **更激进的优化**: Zig允许更底层的优化控制
4. **零成本抽象**: Zig的编译期计算比Go的运行时反射更高效

## 运行基准测试

```bash
# 编译并运行优化版本
zig build bench-sync -Doptimize=ReleaseFast

# 对比原始版本 (备份在 bench_sync_modes_optimized.zig)
# 将原始未优化代码恢复后运行
```

## 最佳实践建议

基于此次优化经验,对于高性能Zig代码的建议:

1. **避免不必要的堆分配**: 优先使用栈、编译期已知大小的缓冲区
2. **使用 inline**: 对热路径上的小函数使用 `inline fn`
3. **启用全优化**: 发布版本使用 `-Doptimize=ReleaseFast`
4. **Profile驱动**: 使用测量数据驱动优化决策
5. **批量操作**: 减少系统调用和API调用次数

## 未来优化方向

虽然已经达到很好的性能,但仍有改进空间:

1. **并行事务**: 利用多核并行处理不同的事务
2. **批量写入**: 使用MDBX的批量API进一步减少开销
3. **预分配**: 对频繁使用的数据结构使用对象池
4. **SIMD优化**: 手动优化关键路径使用SIMD指令
