# 迁移指南

本仓库有两条迁移线，别混淆：

- **[Zig 0.15.2 → 0.16.0 工具链升级](#zig-0152--0160-工具链升级)**：只涉及 Zig 标准库，不改变 zmdbx 自己的 API。
- **[zmdbx API 迁移](#api-迁移指南)**：从旧版 zmdbx API 迁移到最新的类型安全 API。

---

## Zig 0.15.2 → 0.16.0 工具链升级

Zig 0.16 把几乎所有 I/O 搬进了 `std.Io`，并给 I/O 函数加上了必填的 `io` 参数；同时删掉了几个语言特性和内建。
本仓库的 `src/` 是纯 C 绑定，不碰 std 的 I/O，因此**完全没改**；受影响的只有 `build.zig`、`tests/` 和 `examples/`。

### 1. `build.zig`：C 源文件 / include path / libc 从 Compile step 移到 Module

```zig
// 0.15
const lib = b.addLibrary(.{ .name = "zmdbx", .linkage = .static, .root_module = ... });
lib.addCSourceFile(.{ .file = b.path("mdbx/mdbx.c"), .flags = &.{...} });
lib.addIncludePath(b.path("mdbx"));
lib.linkLibC();

// 0.16 —— 全部挂在 module 上（`root_module.link_libc` / `addCSourceFile` / `addIncludePath`）
const module = b.createModule(.{
    .root_source_file = b.path("src/mdbx.zig"),
    .target = target,          // createModule 给 Compile step 用时必须给 target，否则 build 脚本运行时 panic
    .optimize = optimize,
});
module.addCSourceFile(.{ .file = b.path("mdbx/mdbx.c"), .flags = mdbx_c_flags });
module.addIncludePath(b.path("mdbx"));
module.link_libc = true;
```

另外 `b.addTest` / `b.addExecutable` 不再收 `.root_source_file`，改收 `.root_module`。
完整可运行骨架见 `build.zig` 里的 `createZmdbxModule` / `createConsumerModule`。

### 2. `std.fs` → `std.Io`，并且每次调用都要传 `io`

```zig
// 0.15
std.fs.cwd().deleteTree(path) catch {};

// 0.16
std.Io.Dir.cwd().deleteTree(io, path) catch {};
```

`std.io` 和 `std.net` 两个命名空间整个消失；`std.fs.File` → `std.Io.File`，`std.fs.Dir` → `std.Io.Dir`。
本仓库把这件事收敛到两个辅助模块：`tests/util.zig` 和 `examples/util.zig`
（Zig 的 `@import` 不能跨越模块根目录，所以必须各存一份）。

### 3. `std.time` 被 `std.Io.Clock` 取代

```zig
// 0.15
const ms = std.time.milliTimestamp();   // 单调时钟
const s  = std.time.timestamp();        // Unix 纪元秒

// 0.16 —— 注意 Clock 没有 `monotonic`，取值只有 real / awake / boot / cpu_process / cpu_thread
const ms = std.Io.Clock.awake.now(io).toMilliseconds();
const s  = std.Io.Clock.real.now(io).toSeconds();
```

`util.zig` 里的 `millis()` / `timestamp()` 已封装好这两行。

### 4. 其它改到的点

| 0.15 | 0.16 |
|---|---|
| `std.heap.GeneralPurposeAllocator(.{}){}` | `std.heap.DebugAllocator(.{}){}` |
| `std.fmt.allocPrintZ(a, fmt, args)` | `std.fmt.allocPrintSentinel(a, fmt, args, 0)` |
| `std.EnumSet(T)` 上的 `.some_flag` | 已不是枚举，改成 `FlagSet.init(.{ .some_flag = true })` |
| `env.open(path, .defaults, mode)` | `env.open(path, EnvFlagSet.init(.{}), mode)` |
| `pub fn main() !void`（需要 io/分配器时） | `pub fn main(init: std.process.Init) !void`，取 `init.io` / `init.gpa` |

### 5. 迁移中发现的、与 Zig 版本无关的老问题

这些在 0.15 下也编译/通过不了，顺手修掉了：

- `src/cursor.zig` 的 `Cursor.txn()`：C 函数返回 `?*MDBX_txn`，直接当 `*MDBX_txn` 返回是类型错误 → 补上 `.?`。
- `examples/cursor_usage.zig`：把 `Val` 直接按 `{s}` 打印 → 改成 `result.key.toBytes()`。
- `tests/test_cursor.zig`：`cursor.eof()` / `onFirst()` / `onLast()` 返回错误联合，漏了 `try`。
- `tests/test_cursor.zig` "Cursor renew operation"：MDBX **不允许同一线程同时持有两个活跃读事务**
  （会返回 `MDBX_BAD_RSLOT`），测试里先结束旧事务再 `renew` 游标。
- `tests/test_errors.zig` "BadValSize"：1024 字节的键并没有超过 MDBX 默认上限（页 4096 → 2022 字节），
  改成先 `env.getMaxKeySize()` 再构造 `max + 1` 字节的键。
- `tests/test_val_typed.zig`：一处自相矛盾的断言（先断言 `!=`、紧接着断言 `==`）。
- 测试里大量 `.mapsize` / `.read_write` / `.no_overwrite` 之类并不存在的标志字段，
  改成 `setMapsize()` / `beginWriteTxn()` / `PutFlagSet.init(...)`。

---

# API 迁移指南

本文档帮助你从旧版 zmdbx API 迁移到最新的类型安全 API。

## 概述

最新版本的 zmdbx 引入了以下重大改进：

1. **类型安全标志系统** - 使用 `FlagSet` 替代原始整数标志
2. **便捷方法** - 新增 `beginReadTxn()`, `beginWriteTxn()`, `getBytes()` 等
3. **高级 API** - 引入 `EnvBuilder`, `TxnGuard`, `Database` 等高层抽象

## 迁移步骤

### 1. 环境标志

#### 旧 API
```zig
// 使用原始标志值或预定义常量
try env.open("./mydb", .defaults, 0o644);
// 或
try env.open("./mydb", 0, 0o644);
```

#### 新 API
```zig
// 使用类型安全的 EnvFlagSet
try env.open("./mydb", zmdbx.EnvFlagSet.init(.{}), 0o644);

// 或设置特定标志
var env_flags = zmdbx.EnvFlagSet.init(.{});
env_flags.insert(.validation);
env_flags.insert(.no_sub_dir);
try env.open("./mydb", env_flags, 0o644);
```

### 2. 事务创建

#### 旧 API
```zig
// 使用符号常量
var txn = try env.beginTxn(null, .read_write);
defer txn.abort();

var read_txn = try env.beginTxn(null, .read_only);
defer read_txn.abort();
```

#### 新 API (推荐)
```zig
// 使用便捷方法
var txn = try env.beginWriteTxn();
defer txn.abort();

var read_txn = try env.beginReadTxn();
defer read_txn.abort();

// 或使用 TxFlagSet (高级用法)
var tx_flags = zmdbx.TxFlagSet.init(.{ .read_write = true });
var txn = try env.beginTxn(null, tx_flags);
defer txn.abort();
```

### 3. 数据库标志

#### 旧 API
```zig
const dbi = try txn.openDBI(null, .create);
```

#### 新 API
```zig
var db_flags = zmdbx.DBFlagSet.init(.{});
db_flags.insert(.create);
const dbi = try txn.openDBI(null, db_flags);

// 或一次性设置多个标志
var db_flags = zmdbx.DBFlagSet.init(.{});
db_flags.insert(.create);
db_flags.insert(.dup_sort);
const dbi = try txn.openDBI(null, db_flags);
```

### 4. 数据写入标志

#### 旧 API
```zig
try txn.put(dbi, "key", "value", .upsert);
```

#### 新 API
```zig
const put_flags = zmdbx.PutFlagSet.init(.{});
try txn.put(dbi, "key", "value", put_flags);

// 或设置特定标志
var put_flags = zmdbx.PutFlagSet.init(.{});
put_flags.insert(.no_overwrite);  // 不覆盖已存在的键
try txn.put(dbi, "key", "value", put_flags);
```

### 5. 数据读取

#### 旧 API
```zig
const value = try txn.get(dbi, "key");
// 返回 Val 类型,需要转换
const bytes = value.toBytes();
```

#### 新 API (推荐)
```zig
// 直接获取字节切片
const value = try txn.getBytes(dbi, "key");
// value 已经是 []const u8 类型

// 或使用原始方法
const val = try txn.get(dbi, "key");
const bytes = val.toBytes();
```

## 高级 API 使用

### EnvBuilder (构建器模式)

新增的构建器模式让环境配置更加清晰：

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

### TxnGuard (自动事务管理)

使用 `withReadTxn` 和 `withWriteTxn` 自动管理事务生命周期：

```zig
// 读操作 - 自动提交/中止
const result = try env.withReadTxn(struct {
    fn read(txn: *zmdbx.Txn, dbi: zmdbx.DBI) ![]const u8 {
        return try txn.getBytes(dbi, "key");
    }
}.read, dbi);

// 写操作 - 自动提交/中止
try env.withWriteTxn(struct {
    fn write(txn: *zmdbx.Txn, dbi: zmdbx.DBI) !void {
        const put_flags = zmdbx.PutFlagSet.init(.{});
        try txn.put(dbi, "key", "value", put_flags);
    }
}.write, dbi);
```

### Database (高层抽象)

最简单的使用方式：

```zig
var db = try zmdbx.Database.open("./mydb");
defer db.close();

try db.put("key", "value");
const value = try db.get("key");
try db.delete("key");
```

## 完整迁移示例

### 旧代码
```zig
const std = @import("std");
const zmdbx = @import("zmdbx");

pub fn main() !void {
    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open("./mydb", .defaults, 0o644);

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .create);
    try txn.put(dbi, "name", "张三", .upsert);

    const name = try txn.get(dbi, "name");
    std.debug.print("name: {s}\n", .{name.toBytes()});

    try txn.commit();
}
```

### 新代码
```zig
const std = @import("std");
const zmdbx = @import("zmdbx");

pub fn main() !void {
    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open("./mydb", zmdbx.EnvFlagSet.init(.{}), 0o644);

    var txn = try env.beginWriteTxn();
    defer txn.abort();

    var db_flags = zmdbx.DBFlagSet.init(.{});
    db_flags.insert(.create);
    const dbi = try txn.openDBI(null, db_flags);

    const put_flags = zmdbx.PutFlagSet.init(.{});
    try txn.put(dbi, "name", "张三", put_flags);

    const name = try txn.getBytes(dbi, "name");
    std.debug.print("name: {s}\n", .{name});

    try txn.commit();
}
```

## 兼容性说明

- ✅ 新旧 API 可以共存,逐步迁移
- ✅ 旧 API 仍然可用,不会立即移除
- ⚠️ 建议新项目直接使用新 API
- ⚠️ 旧 API 未来可能被标记为 deprecated

## 迁移检查清单

- [ ] 将环境标志更新为 `EnvFlagSet`
- [ ] 将事务创建更新为 `beginReadTxn()`/`beginWriteTxn()`
- [ ] 将数据库标志更新为 `DBFlagSet`
- [ ] 将写入标志更新为 `PutFlagSet`
- [ ] 将 `get()` 替换为 `getBytes()` (如果适用)
- [ ] 考虑使用 `EnvBuilder` 简化环境配置
- [ ] 考虑使用 `withReadTxn`/`withWriteTxn` 简化事务管理
- [ ] 运行测试确保迁移正确

## 获取帮助

如果在迁移过程中遇到问题：

1. 查看 `examples/` 目录中的最新示例
2. 阅读 [README.md](../README.md) 中的 API 参考
3. 提交 Issue: https://github.com/sunvim/zmdbx/issues

## 性能提示

新 API 保持了零成本抽象：

- `FlagSet` 在编译时优化为位标志
- 便捷方法会被内联
- 没有额外的运行时开销

可以放心使用新 API,不会影响性能！
