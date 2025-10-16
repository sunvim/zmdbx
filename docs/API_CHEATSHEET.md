# zmdbx API 速查表

快速参考最常用的 zmdbx API 和使用模式。

## 目录

- [环境管理](#环境管理)
- [事务操作](#事务操作)
- [数据操作](#数据操作)
- [游标遍历](#游标遍历)
- [标志系统](#标志系统)
- [错误处理](#错误处理)

---

## 环境管理

### 创建和打开环境

```zig
// 基本用法
var env = try zmdbx.Env.init();
defer env.deinit();
try env.open("./mydb", zmdbx.EnvFlagSet.init(.{}), 0o644);

// 配置环境参数
try env.setMaxdbs(10);
try env.setGeometry(.{
    .lower = 1024 * 1024,      // 1MB 最小
    .now = 10 * 1024 * 1024,   // 10MB 初始
    .upper = 100 * 1024 * 1024, // 100MB 最大
    .growth_step = 1024 * 1024,
    .shrink_threshold = -1,
    .pagesize = -1,
});
```

### 使用构建器模式

```zig
var env = try zmdbx.EnvBuilder.init()
    .setMaxdbs(10)
    .setGeometry(.{ /* ... */ })
    .build("./mydb", zmdbx.EnvFlagSet.init(.{}), 0o644);
defer env.deinit();
```

### 常用环境方法

```zig
try env.sync();                          // 强制同步到磁盘
try env.setSyncPeriod(60_000);          // 设置同步周期(毫秒)
try env.setMaxReaders(126);             // 设置最大读者数
const path = try env.getPath();          // 获取数据库路径
const max_key = env.getMaxKeySize();     // 获取最大键大小
```

---

## 事务操作

### 创建事务

```zig
// 读写事务
var txn = try env.beginWriteTxn();
defer txn.abort();  // 确保异常时中止

// 只读事务
var read_txn = try env.beginReadTxn();
defer read_txn.abort();
```

### 自动事务管理

```zig
// 只读事务 - 自动管理
const result = try env.withReadTxn(struct {
    fn read(txn: *zmdbx.Txn, dbi: zmdbx.DBI) ![]const u8 {
        return try txn.getBytes(dbi, "key");
    }
}.read, dbi);

// 读写事务 - 自动管理
try env.withWriteTxn(struct {
    fn write(txn: *zmdbx.Txn, dbi: zmdbx.DBI) !void {
        try txn.put(dbi, "key", "value", zmdbx.PutFlagSet.init(.{}));
    }
}.write, dbi);
```

### 提交和中止

```zig
try txn.commit();  // 提交更改
txn.abort();       // 中止事务(总是成功)
```

### 打开数据库实例

```zig
// 基本用法
var db_flags = zmdbx.DBFlagSet.init(.{});
db_flags.insert(.create);
const dbi = try txn.openDBI(null, db_flags);

// 命名数据库
const dbi = try txn.openDBI("users", db_flags);
```

---

## 数据操作

### 写入数据

```zig
// 基本写入
const put_flags = zmdbx.PutFlagSet.init(.{});
try txn.put(dbi, "name", "张三", put_flags);

// 不覆盖已存在的键
var put_flags = zmdbx.PutFlagSet.init(.{});
put_flags.insert(.no_overwrite);
try txn.put(dbi, "id", "001", put_flags);

// 追加模式(性能优化)
var put_flags = zmdbx.PutFlagSet.init(.{});
put_flags.insert(.append);
try txn.put(dbi, "log", "entry", put_flags);
```

### 读取数据

```zig
// 读取为字节切片(推荐)
const value = try txn.getBytes(dbi, "name");
std.debug.print("{s}\n", .{value});

// 读取为 Val 类型
const val = try txn.get(dbi, "name");
const bytes = val.toBytes();
```

### 删除数据

```zig
// 删除键
try txn.del(dbi, "name", null);

// 删除特定值(仅用于 dup_sort 数据库)
try txn.del(dbi, "tags", "old_tag");
```

### 检查键是否存在

```zig
const exists = txn.get(dbi, "key") catch |err| switch (err) {
    error.NotFound => false,
    else => return err,
};
```

### 类型化数据操作 (Val API)

#### 写入数值类型

```zig
// 使用Val类型化API写入
const age: u32 = 25;
const score: i64 = -1000;
const level: u8 = 5;

// 创建Val并写入
const age_val = zmdbx.Val.from_u32(age);
try txn.put(dbi, "age", age_val.toBytes(), put_flags);

// 其他支持的类型: i8, i16, i32, i64, i128, u8, u16, u32, u64, u128
```

#### 读取数值类型

```zig
// 读取并转换为特定类型
const val = try txn.get(dbi, "age");
const age = try val.to_u32();  // 自动验证长度

// 处理错误情况
const score_val = try txn.get(dbi, "score");
const score = score_val.to_i64() catch |err| switch (err) {
    error.InvalidDataLength => {
        std.debug.print("数据长度不匹配\n", .{});
        return err;
    },
    else => return err,
};
```

#### 往返转换示例

```zig
// 类型安全的往返转换
const original: i32 = -12345;

// 转换为Val
const val = zmdbx.Val.from_i32(original);

// 存储到数据库
try txn.put(dbi, "number", val.toBytes(), put_flags);

// 从数据库读取
const stored_val = try txn.get(dbi, "number");

// 转换回i32
const retrieved = try stored_val.to_i32();

// retrieved == original  ✓
```

#### 支持的类型

| 类型 | from方法 | to方法 | 示例 |
|------|---------|--------|------|
| i8 | `from_i8(v)` | `to_i8()` | -128 ~ 127 |
| i16 | `from_i16(v)` | `to_i16()` | -32768 ~ 32767 |
| i32 | `from_i32(v)` | `to_i32()` | ±21亿 |
| i64 | `from_i64(v)` | `to_i64()` | ±922京 |
| i128 | `from_i128(v)` | `to_i128()` | 超大整数 |
| u8 | `from_u8(v)` | `to_u8()` | 0 ~ 255 |
| u16 | `from_u16(v)` | `to_u16()` | 0 ~ 65535 |
| u32 | `from_u32(v)` | `to_u32()` | 0 ~ 42亿 |
| u64 | `from_u64(v)` | `to_u64()` | 0 ~ 1844京 |
| u128 | `from_u128(v)` | `to_u128()` | 超大无符号整数 |

⚠️ **注意**: 所有类型化方法使用原生字节序，跨架构场景需要注意兼容性。

---

## 游标遍历

### 打开游标

```zig
var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
defer cursor.close();
```

### 遍历所有数据

```zig
var result = try cursor.get(null, null, .first);
while (true) {
    std.debug.print("key: {s}, value: {s}\n", .{result.key, result.data});

    result = cursor.get(null, null, .next) catch |err| {
        if (err == error.NotFound) break;
        return err;
    };
}
```

### 范围查询

```zig
// 查找 >= 指定键的记录
var result = try cursor.get("user:100", null, .set_range);
while (true) {
    // 检查是否仍在范围内
    if (!std.mem.startsWith(u8, result.key, "user:")) break;

    std.debug.print("key: {s}\n", .{result.key});

    result = cursor.get(null, null, .next) catch |err| {
        if (err == error.NotFound) break;
        return err;
    };
}
```

### 常用游标操作

```zig
// 定位到第一条记录
var result = try cursor.get(null, null, .first);

// 定位到最后一条记录
var result = try cursor.get(null, null, .last);

// 定位到指定键
var result = try cursor.get("key", null, .set);

// 向前/向后移动
var result = try cursor.get(null, null, .next);
var result = try cursor.get(null, null, .prev);

// 使用游标写入
try cursor.put("key", "value", zmdbx.PutFlagSet.init(.{}));

// 删除当前记录
try cursor.del(zmdbx.PutFlagSet.init(.{}));
```

---

## 标志系统

### EnvFlagSet (环境标志)

```zig
var env_flags = zmdbx.EnvFlagSet.init(.{});
env_flags.insert(.validation);      // 开启验证
env_flags.insert(.no_sub_dir);      // 单文件模式
env_flags.insert(.read_only);       // 只读模式
env_flags.insert(.exclusive);       // 独占访问
```

### DBFlagSet (数据库标志)

```zig
var db_flags = zmdbx.DBFlagSet.init(.{});
db_flags.insert(.create);           // 创建数据库
db_flags.insert(.dup_sort);         // 允许重复键
db_flags.insert(.integer_key);      // 键为整数
db_flags.insert(.reverse_key);      // 键降序排列
```

### TxFlagSet (事务标志)

```zig
var tx_flags = zmdbx.TxFlagSet.init(.{});
tx_flags.insert(.read_write);       // 读写事务
tx_flags.insert(.try_flag);         // 非阻塞
tx_flags.insert(.read_only);        // 只读事务
```

### PutFlagSet (写入标志)

```zig
var put_flags = zmdbx.PutFlagSet.init(.{});
put_flags.insert(.no_overwrite);    // 仅插入(不覆盖)
put_flags.insert(.no_dup_data);     // 不插入重复值
put_flags.insert(.current);         // 更新当前游标位置
put_flags.insert(.append);          // 追加(性能优化)
put_flags.insert(.append_dup);      // 追加重复值
```

---

## 错误处理

### 常见错误

```zig
const value = txn.get(dbi, "key") catch |err| switch (err) {
    error.NotFound => {
        // 键不存在
        std.debug.print("Key not found\n", .{});
        return;
    },
    error.KeyExists => {
        // 键已存在(使用 no_overwrite 时)
        return err;
    },
    error.MapFull => {
        // 数据库已满
        return err;
    },
    else => return err,
};
```

### 事务错误处理

```zig
var txn = try env.beginWriteTxn();
errdefer txn.abort();  // 错误时自动中止

// 执行操作...
try txn.put(dbi, "key", "value", put_flags);

try txn.commit();
```

---

## 性能优化技巧

### 批量操作

```zig
// 在单个事务中批量写入
var txn = try env.beginWriteTxn();
defer txn.abort();

const dbi = try txn.openDBI(null, db_flags);

var i: usize = 0;
while (i < 10000) : (i += 1) {
    const key = try std.fmt.allocPrint(allocator, "key:{d}", .{i});
    defer allocator.free(key);

    try txn.put(dbi, key, "value", put_flags);
}

try txn.commit();
```

### 使用追加模式

```zig
// 如果键是递增的,使用追加模式
var put_flags = zmdbx.PutFlagSet.init(.{});
put_flags.insert(.append);

var i: usize = 0;
while (i < 10000) : (i += 1) {
    const key = try std.fmt.allocPrint(allocator, "{d:0>10}", .{i});
    defer allocator.free(key);

    try txn.put(dbi, key, "value", put_flags);
}
```

### 调整数据库几何参数

```zig
try env.setGeometry(.{
    .lower = 10 * 1024 * 1024,      // 10MB 最小
    .now = 100 * 1024 * 1024,       // 100MB 初始
    .upper = 1024 * 1024 * 1024,    // 1GB 最大
    .growth_step = 10 * 1024 * 1024, // 10MB 增长步长
    .shrink_threshold = -1,
    .pagesize = -1,
});
```

### 配置同步策略

```zig
// 设置同步周期(毫秒)
try env.setSyncPeriod(5000);  // 每5秒同步一次

// 设置同步字节数
try env.setSyncBytes(16 * 1024 * 1024);  // 每16MB同步一次
```

---

## 完整示例

```zig
const std = @import("std");
const zmdbx = @import("zmdbx");

pub fn main() !void {
    // 创建并配置环境
    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.setMaxdbs(10);
    try env.open("./mydb", zmdbx.EnvFlagSet.init(.{}), 0o644);

    // 写入数据
    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        var db_flags = zmdbx.DBFlagSet.init(.{});
        db_flags.insert(.create);
        const dbi = try txn.openDBI(null, db_flags);

        const put_flags = zmdbx.PutFlagSet.init(.{});
        try txn.put(dbi, "name", "张三", put_flags);
        try txn.put(dbi, "age", "25", put_flags);

        try txn.commit();
    }

    // 读取数据
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));

        const name = try txn.getBytes(dbi, "name");
        const age = try txn.getBytes(dbi, "age");

        std.debug.print("name: {s}, age: {s}\n", .{name, age});
    }
}
```

---

## 快速链接

- [完整文档](../README.md)
- [API 迁移指南](MIGRATION.md)
- [示例代码](../examples/)
- [性能基准](../BENCHMARKS.md)
