# MDBX 配置快速参考卡

## 🚀 同步模式选择

| 模式 | 写入性能 | 断电安全 | 使用场景 | 配置代码 |
|------|----------|----------|----------|----------|
| **SYNC_DURABLE** | ⭐⭐⭐ | ✅ 100% | 金融/支付 | `try env.open(path, .defaults, 0o755);` |
| **SAFE_NOSYNC** | ⭐⭐⭐⭐⭐ | ⚠️ 异步 | **生产推荐** | `try env.open(path, .write_map, 0o755);`<br>`try env.setFlags(.safe_no_sync, true);` |
| **NOMETASYNC** | ⭐⭐⭐⭐ | ⚠️ 元数据延迟 | 高频写入 | `try env.open(path, .write_map, 0o755);`<br>`try env.setFlags(.no_meta_sync, true);` |
| **UTTERLY_NOSYNC** | ⭐⭐⭐⭐⭐ | ❌ 无保证 | 测试/缓存 | `try env.open(path, .write_map, 0o755);`<br>`try env.setFlags(.utterly_no_sync, true);` |

---

## ⚙️ 性能参数速查

### 高性能配置 (推荐生产)

```zig
// 几何参数
try env.setGeometry(.{
    .lower = 100 * 1024 * 1024,        // 100MB
    .now = 1024 * 1024 * 1024,         // 1GB
    .upper = 100 * 1024 * 1024 * 1024, // 100GB
    .growth_step = 256 * 1024 * 1024,  // 256MB
    .shrink_threshold = -1,
    .pagesize = -1,
});

// 性能调优 (默认值的 2-4 倍)
try env.setOption(.OptTxnDpLimit, 262144);      // 默认 65536
try env.setOption(.OptTxnDpInitial, 16384);     // 默认 1024
try env.setOption(.OptDpReserveLimit, 8192);    // 默认 1024
try env.setOption(.OptLooseLimit, 128);         // 默认 64

// 同步策略
try env.setSyncBytes(64 * 1024 * 1024);         // 64MB
try env.setSyncPeriod(30 * 65536);              // 30秒
```

### 保守配置 (金融级)

```zig
try env.setGeometry(.{
    .lower = 50 * 1024 * 1024,
    .now = 500 * 1024 * 1024,
    .upper = 10 * 1024 * 1024 * 1024,
    .growth_step = 100 * 1024 * 1024,
    .shrink_threshold = -1,
    .pagesize = -1,
});

// 使用默认参数即可
try env.open(path, .defaults, 0o755);
```

---

## 📊 性能基准 (参考值)

### 硬件: NVMe SSD + 32GB RAM

| 操作类型 | SYNC_DURABLE | SAFE_NOSYNC | UTTERLY_NOSYNC |
|---------|--------------|-------------|----------------|
| 顺序写入 | 10,000 ops/s | 150,000 ops/s | 500,000 ops/s |
| 随机写入 | 8,000 ops/s | 80,000 ops/s | 200,000 ops/s |
| 顺序读取 | 500,000 ops/s | 500,000 ops/s | 500,000 ops/s |
| 随机读取 | 300,000 ops/s | 300,000 ops/s | 300,000 ops/s |

---

## 🛡️ 数据安全保证

### SAFE_NOSYNC 工作原理

```
时间轴:
0s ───→ 写入100MB数据到内存 ───→ 30s自动fsync ───→ 继续写入
       ↑                        ↑
       进程崩溃: 数据安全       断电: 丢失0-30s数据
       (MDBX WAL 保证)          (操作系统未刷盘)
```

### 安全性对比

| 场景 | SYNC_DURABLE | SAFE_NOSYNC | UTTERLY_NOSYNC |
|------|--------------|-------------|----------------|
| 进程崩溃 | ✅ 安全 | ✅ 安全 (WAL) | ✅ 安全 (内存映射) |
| 系统断电 | ✅ 安全 | ⚠️ 丢失 <同步周期 | ❌ 全部丢失 |
| 磁盘损坏 | ❌ 需备份 | ❌ 需备份 | ❌ 需备份 |

---

## 🔧 常用操作

### 手动同步

```zig
// 强制同步到磁盘 (阻塞)
try env.sync(true, false);

// 非阻塞同步 (后台异步)
try env.sync(true, true);
```

### 查看当前配置

```zig
const txn_dp = try env.getOption(.OptTxnDpLimit);
const sync_bytes = try env.getSyncBytes();
const sync_period = try env.getSyncPeriod();

std.debug.print("TxnDpLimit: {}\n", .{txn_dp});
std.debug.print("SyncBytes: {} MB\n", .{sync_bytes / (1024 * 1024)});
std.debug.print("SyncPeriod: {} 秒\n", .{sync_period / 65536});
```

### 优化事务

```zig
// 大批量写入使用单个事务
var txn = try env.beginTxn(null, .read_write);
defer txn.abort();

const dbi = try txn.openDBI(null, .create);

var i: usize = 0;
while (i < 1000000) : (i += 1) {
    try txn.put(dbi, key, value, .upsert);
}

try txn.commit();
```

---

## 📈 调优建议

### 根据写入量调整同步阈值

| 写入速度 | SyncBytes | SyncPeriod | 最大丢失 |
|---------|-----------|------------|----------|
| 低 (<1MB/s) | 16MB | 5秒 | 5秒 |
| 中 (1-10MB/s) | 64MB | 30秒 | 30秒 |
| 高 (>10MB/s) | 128MB | 60秒 | 60秒 |

### 根据内存调整脏页上限

| 可用内存 | OptTxnDpLimit | 内存占用 |
|---------|---------------|----------|
| < 4GB | 65536 (默认) | ~256MB |
| 4-16GB | 131072 (2x) | ~512MB |
| > 16GB | 262144 (4x) | ~1GB |

---

## 🚨 常见问题

### Q: 为什么性能没达到预期?

**排查清单:**
1. ✅ 检查磁盘类型 (SSD > HDD)
2. ✅ 确认编译优化 (`-O2` 或 `-O3`)
3. ✅ 验证同步模式 (是否启用 SAFE_NOSYNC)
4. ✅ 检查事务大小 (避免过小的事务)
5. ✅ 确认参数生效 (使用 `getOption` 验证)

### Q: SAFE_NOSYNC 安全吗?

**安全性保证:**
- ✅ 进程崩溃: 100% 安全 (MDBX 内置 WAL)
- ⚠️ 系统断电: 丢失最后一个同步周期的数据
- 💡 建议: 关键数据用 SYNC_DURABLE, 日志类数据用 SAFE_NOSYNC

### Q: 如何选择同步周期?

**选择策略:**
- 金融数据: 不使用 (SYNC_DURABLE)
- 用户数据: 5秒 + 16MB
- 分析日志: 30秒 + 64MB
- 临时缓存: 不需要 (UTTERLY_NOSYNC)

---

## 📦 测试命令

```bash
# 运行基础性能测试
zig build bench

# 运行同步模式对比测试
zig build bench-sync

# 运行单元测试
zig build test

# 查看帮助
zig build --help
```

---

## 📚 相关文档

- [完整性能指南](./PERFORMANCE_GUIDE.md)
- [代码示例](../examples/high_performance_config.zig)
- [MDBX 官方文档](https://erthink.github.io/libmdbx/)

---

**快速参考版本:** 1.0.0
**最后更新:** 2025-10-15
