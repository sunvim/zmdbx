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
