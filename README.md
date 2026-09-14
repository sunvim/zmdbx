# zmdbx

🚀 **高性能、类型安全的 MDBX Zig 语言绑定**

`zmdbx` 是 [libmdbx](https://github.com/erthink/libmdbx) 的 Zig 语言绑定库，提供了简洁、符合 Zig 风格的 API，完全兼容 Zig 0.16.0。

## ✨ 特性

- ✅ **类型安全**: 充分利用 Zig 的类型系统，避免运行时错误
- ✅ **零成本抽象**: 直接映射到 C API，无性能损失
- ✅ **符合 Zig 风格**: 遵循 Zig 命名规范和错误处理模式
- ✅ **完整的 API 覆盖**: 支持环境管理、事务、游标等核心功能
- ✅ **优秀的文档**: 完整的中文注释和使用示例
- ✅ **经过测试**: 包含单元测试和性能压测

## ⚡ 性能表现

> 下面所有数字都是 **best-of-5**（1 轮热身 + 4 轮测量取最快）的实测值，
> 环境：Apple M3 Max / macOS 26 / Zig 0.16.0 / `-Doptimize=ReleaseFast`。
> 热路径零堆分配，计时区段不含建库与灌数据。复现方式见 [BENCHMARKS.md](BENCHMARKS.md)。

### 读写吞吐（推荐生产配置：`write_map` + `safe_no_sync`）

| 操作 | 吞吐量 | 单次耗时 |
|------|--------|---------|
| 顺序写入 (10万条) | ~8,300,000 ops/s | 120 ns |
| 随机写入 (10万条) | ~4,000,000 ops/s | 250 ns |
| 顺序读取 (10万条) | ~10,000,000 ops/s | 100 ns |
| 随机读取 (5万次) | ~5,800,000 ops/s | 172 ns |
| 混合操作 (读写删 5万次) | ~8,800,000 ops/s | 113 ns |
| 批量删除 (5万条) | ~3,700,000 ops/s | 270 ns |

绑定本身的开销约等于零：同一份逻辑直接用 C API 写，`mdbx_put`/`mdbx_get`
分别是 84ns / 90ns，走 Zig 封装是 85ns / 91ns（差 1~2% 的测量噪声量级）。

> ⚠️ `MDBX_WRITEMAP` 对写入影响很大：实测同一个 100 万次写入的单事务，
> 开 `write_map` 是 84ns/op，不开是 165ns/op（约 2 倍）。

### 同步模式对比

| 同步模式 | 操作数 | 吞吐量 | 数据安全等级 |
|---------|--------|--------|-------------|
| **SAFE_NOSYNC** 🏆 | 10万条/12.1ms | **~8,300,000 ops/s** | 🟡 断电丢失<30s |
| UTTERLY_NOSYNC | 10万条/12.1ms | ~8,200,000 ops/s | 🔴 断电全丢失 |
| NOMETASYNC | 10万条/12.7ms | ~7,900,000 ops/s | 🟠 元数据延迟 |
| SYNC_DURABLE | 1万条/1.5ms | ~6,900,000 ops/s | 🟢 100% 安全 |

小事务（每 10 条提交一次）下差距会拉开：SAFE_NOSYNC 约 1,850,000 ops/s，
SYNC_DURABLE 约 130,000 ops/s（**14 倍**）。批量越大差距越小，
10 万条一个事务时两者只差 1.3 倍。

**配置建议**：
- 🟢 **金融/支付系统**：使用 SYNC_DURABLE（默认）
- 🟡 **日志/消息队列**：使用 SAFE_NOSYNC + `write_map`
- 🟠 **高频写入场景**：使用 NOMETASYNC

运行完整对比测试：
```bash
zig build bench-all -Doptimize=ReleaseFast
```

更多详情请参阅 [BENCHMARKS.md](BENCHMARKS.md)。

## 📦 安装

### 使用 Zig 包管理器

1. 将 zmdbx 添加到你的项目：

```bash
zig fetch --save https://github.com/sunvim/zmdbx/archive/main.tar.gz
```

2. 在 `build.zig` 中添加依赖：

```zig
const zmdbx = b.dependency("zmdbx", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zmdbx", zmdbx.module("zmdbx"));
```

### 手动安装

1. 克隆仓库并初始化子模块：

```bash
git clone https://github.com/sunvim/zmdbx.git
cd zmdbx
```

2. 构建库：

```bash
zig build
```

## 🚀 快速开始

```zig
const std = @import("std");
const zmdbx = @import("zmdbx");

pub fn main() !void {
    // 1. 创建环境
    var env = try zmdbx.Env.init();
    defer env.deinit();

    // 2. 打开数据库
    try env.open("./mydb", zmdbx.EnvFlagSet.init(.{}), 0o644);

    // 3. 开始写事务 (新API: beginWriteTxn)
    var txn = try env.beginWriteTxn();
    defer txn.abort(); // 确保异常时中止

    // 4. 打开数据库实例
    var db_flags = zmdbx.DBFlagSet.init(.{});
    db_flags.insert(.create);
    const dbi = try txn.openDBI(null, db_flags);

    // 5. 写入数据
    const put_flags = zmdbx.PutFlagSet.init(.{});
    try txn.put(dbi, "name", "张三", put_flags);
    try txn.put(dbi, "age", "25", put_flags);

    // 6. 读取数据 (新API: getBytes)
    const name = try txn.getBytes(dbi, "name");
    std.debug.print("name: {s}\n", .{name});

    // 7. 提交事务
    try txn.commit();
}
```

## 📚 文档

**快速导航：**
- 📖 [API 速查表](docs/API_CHEATSHEET.md) - 常用 API 快速参考
- 🔄 [迁移指南](docs/MIGRATION.md) - 从旧版本升级指南
- 📊 [性能基准](BENCHMARKS.md) - 详细性能测试结果

### 核心概念

#### 环境 (Environment)

环境是 MDBX 数据库的顶层容器：

```zig
var env = try zmdbx.Env.init();
defer env.deinit();

// 设置数据库大小
try env.setGeometry(.{
    .lower = 1024 * 1024,      // 最小 1MB
    .now = 10 * 1024 * 1024,   // 初始 10MB
    .upper = 100 * 1024 * 1024, // 最大 100MB
    .growth_step = 1024 * 1024,
    .shrink_threshold = -1,
    .pagesize = -1,
});

try env.open("./mydb", .defaults, 0o644);
```

#### 事务 (Transaction)

事务提供 ACID 保证：

```zig
// 读写事务 (新API: 更简洁的方法)
var write_txn = try env.beginWriteTxn();
defer write_txn.abort();

// 只读事务 (新API: 更简洁的方法)
var read_txn = try env.beginReadTxn();
defer read_txn.abort();

// 或使用传统方式
var txn = try env.beginTxn(null, zmdbx.TxFlagSet.init(.{ .read_write = true }));
defer txn.abort();
```

#### 游标 (Cursor)

游标用于高效遍历数据：

```zig
var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
defer cursor.close();

// 遍历所有记录
var result = try cursor.get(null, null, .first);
while (true) {
    std.debug.print("key: {s}, value: {s}\n", .{result.key, result.data});
    result = cursor.get(null, null, .next) catch |err| {
        if (err == error.NotFound) break;
        return err;
    };
}
```

### 高级 API

#### EnvBuilder (构建器模式)

使用构建器模式配置和创建环境：

```zig
var env = try zmdbx.EnvBuilder.init()
    .setMaxdbs(10)
    .setGeometry(.{
        .lower = 1024 * 1024,
        .now = 10 * 1024 * 1024,
        .upper = 100 * 1024 * 1024,
        .growth_step = 1024 * 1024,
        .shrink_threshold = -1,
        .pagesize = -1,
    })
    .build("./mydb", zmdbx.EnvFlagSet.init(.{}), 0o644);
defer env.deinit();
```

#### TxnGuard (自动提交/中止)

自动管理事务生命周期：

```zig
// 使用 withReadTxn 进行只读操作
const result = try env.withReadTxn(struct {
    fn read(txn: *zmdbx.Txn, dbi: zmdbx.DBI) ![]const u8 {
        return try txn.getBytes(dbi, "key");
    }
}.read, dbi);

// 使用 withWriteTxn 进行写操作
try env.withWriteTxn(struct {
    fn write(txn: *zmdbx.Txn, dbi: zmdbx.DBI) !void {
        const put_flags = zmdbx.PutFlagSet.init(.{});
        try txn.put(dbi, "key", "value", put_flags);
    }
}.write, dbi);
```

#### Database (高层抽象)

简化的数据库操作接口：

```zig
var db = try zmdbx.Database.open("./mydb");
defer db.close();

// 直接进行读写操作
try db.put("key", "value");
const value = try db.get("key");
try db.delete("key");
```

#### Val (类型化数据) ⭐ 新功能

Val 提供类型安全的数值类型转换，让您可以直接存储和读取整数类型，无需手动序列化：

```zig
// ===== 改进前：繁琐的手动转换 =====
const age: u32 = 25;
const age_bytes = std.mem.asBytes(&age);
try txn.put(dbi, "age", age_bytes, put_flags);

const val = try txn.get(dbi, "age");
const bytes = val.toBytes();
const age_read = std.mem.bytesToValue(u32, bytes[0..@sizeOf(u32)]);

// ===== 改进后：简洁的类型化API =====
const age: u32 = 25;
const age_val = zmdbx.Val.from_u32(age);
try txn.put(dbi, "age", age_val.toBytes(), put_flags);

const val = try txn.get(dbi, "age");
const age_read = try val.to_u32();  // 自动验证长度！
```

**支持的类型**：
- 有符号整数：`i8`, `i16`, `i32`, `i64`, `i128`
- 无符号整数：`u8`, `u16`, `u32`, `u64`, `u128`
- 浮点数：`f16`, `f32`, `f64`, `f80`, `f128`, `c_longdouble`

**实际使用示例**：

```zig
// 游戏玩家数据（整数）
try txn.put(dbi, "player:score", zmdbx.Val.from_i32(1500).toBytes(), put_flags);
try txn.put(dbi, "player:level", zmdbx.Val.from_u8(25).toBytes(), put_flags);
try txn.put(dbi, "player:gold", zmdbx.Val.from_u64(999999).toBytes(), put_flags);

// 读取整数
const score = try (try txn.get(dbi, "player:score")).to_i32();
const level = try (try txn.get(dbi, "player:level")).to_u8();
const gold = try (try txn.get(dbi, "player:gold")).to_u64();

std.debug.print("分数: {}, 等级: {}, 金币: {}\n", .{score, level, gold});

// 物理量存储（浮点数）
try txn.put(dbi, "physics:temperature", zmdbx.Val.from_f32(36.5).toBytes(), put_flags);
try txn.put(dbi, "physics:pi", zmdbx.Val.from_f64(3.141592653589793).toBytes(), put_flags);
try txn.put(dbi, "physics:planck", zmdbx.Val.from_f128(6.62607015e-34).toBytes(), put_flags);

// 读取浮点数
const temp = try (try txn.get(dbi, "physics:temperature")).to_f32();
const pi = try (try txn.get(dbi, "physics:pi")).to_f64();
const planck = try (try txn.get(dbi, "physics:planck")).to_f128();

std.debug.print("温度: {}°C, 圆周率: {}, 普朗克常数: {}\n", .{temp, pi, planck});
```

⚠️ **注意**：所有类型化方法使用原生字节序，跨架构场景需要注意兼容性。

### API 参考

#### Env (环境)

| 方法 | 描述 |
|------|------|
| `init()` | 创建新环境 |
| `deinit()` | 关闭环境 |
| `open(path, flags, mode)` | 打开数据库 |
| `setGeometry(geo)` | 设置数据库几何参数 |
| `setMaxdbs(n)` | 设置最大数据库数量 |
| `beginTxn(parent, flags)` | 开始新事务 (传统方式) |
| `beginReadTxn()` | **新增** 开始只读事务 (便捷方法) |
| `beginWriteTxn()` | **新增** 开始读写事务 (便捷方法) |
| `withReadTxn(fn, args)` | **新增** 自动管理只读事务 |
| `withWriteTxn(fn, args)` | **新增** 自动管理写事务 |
| `setOption(option, value)` | 设置环境选项 |
| `getOption(option)` | 获取环境选项 |

#### Txn (事务)

| 方法 | 描述 |
|------|------|
| `init(env, parent, flags)` | 创建事务 |
| `commit()` | 提交事务 |
| `abort()` | 中止事务 |
| `openDBI(name, flags)` | 打开数据库实例 |
| `get(dbi, key)` | 获取数据 (返回 Val) |
| `getBytes(dbi, key)` | **新增** 获取数据 (返回 []const u8) |
| `put(dbi, key, data, flags)` | 写入数据 |
| `del(dbi, key, data)` | 删除数据 |

#### Cursor (游标)

| 方法 | 描述 |
|------|------|
| `open(txn, dbi)` | 打开游标 |
| `close()` | 关闭游标 |
| `get(key, data, op)` | 获取数据 |
| `put(key, data, flags)` | 写入数据 |
| `del(flags)` | 删除当前项 |

### 类型安全标志系统

zmdbx 提供了类型安全的标志集合,避免了手动管理位标志的错误:

#### EnvFlagSet (环境标志)

```zig
var env_flags = zmdbx.EnvFlagSet.init(.{});
env_flags.insert(.validation);      // 开启验证
env_flags.insert(.no_sub_dir);      // 不使用子目录
env_flags.remove(.validation);      // 移除验证标志

// 检查标志
if (env_flags.contains(.no_sub_dir)) {
    // ...
}
```

#### DBFlagSet (数据库标志)

```zig
var db_flags = zmdbx.DBFlagSet.init(.{});
db_flags.insert(.create);           // 如果不存在则创建
db_flags.insert(.dup_sort);         // 允许重复键(排序)
```

#### TxFlagSet (事务标志)

```zig
var tx_flags = zmdbx.TxFlagSet.init(.{});
tx_flags.insert(.read_write);       // 读写事务
tx_flags.insert(.try_flag);         // 尝试获取锁
```

#### PutFlagSet (写入标志)

```zig
var put_flags = zmdbx.PutFlagSet.init(.{});
put_flags.insert(.no_overwrite);    // 不覆盖已存在的键
put_flags.insert(.append);          // 追加到末尾(性能优化)
```

## 📖 示例

查看 `examples/` 目录获取完整示例：

- **basic_usage.zig** - 基本使用示例 (使用最新API)
- **cursor_usage.zig** - 游标遍历示例
- **batch_operations.zig** - 批量操作示例
- **high_performance_config.zig** - 高性能配置示例

### 运行示例

使用项目依赖运行示例：

```bash
# 基本使用
zig build run-basic

# 游标使用
zig build run-cursor

# 批量操作
zig build run-batch

# 高性能配置
zig build run-perf
```

或者手动编译运行（Zig 0.16 写法）：

```bash
zig build-exe examples/basic_usage.zig --dep zmdbx -Mroot=examples/basic_usage.zig -Mzmdbx=src/mdbx.zig
./basic_usage
```

## 🧪 测试

### 运行单元测试

```bash
zig build test
```

### 运行性能压测

**重要**: 基准测试必须用 ReleaseFast 模式运行。Debug 模式下分配器带泄漏检查、
Zig 侧无优化，数字会低 1~3 个数量级（基准程序检测到非 Release 构建时会自己打警告）：

```bash
# 推荐：一次跑完全部 4 个基准
zig build bench-all -Doptimize=ReleaseFast

# 也可以单独跑
zig build bench       -Doptimize=ReleaseFast   # 6 个标准读写场景
zig build bench-sync  -Doptimize=ReleaseFast   # 4 种同步模式
zig build bench-txn   -Doptimize=ReleaseFast   # 事务批量大小 × 同步模式
```

更多详情请参阅 [BENCHMARKS.md](BENCHMARKS.md)。

## 🛠 开发

### 构建

```bash
zig build
```

### 清理

```bash
zig build clean
```

### 代码格式化

```bash
zig fmt src/*.zig
```

## 📝 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献

欢迎贡献！请随时提交 Issue 或 Pull Request。

### 贡献指南

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交你的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启一个 Pull Request

## 🙏 致谢

- [libmdbx](https://github.com/erthink/libmdbx) - 优秀的嵌入式数据库引擎
- [Zig](https://ziglang.org/) - 强大的系统编程语言

## 📮 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 Issue: https://github.com/sunvim/zmdbx/issues
- Email: mobussun@gmail.com

---

⭐ 如果这个项目对你有帮助，请给它一个星标！
